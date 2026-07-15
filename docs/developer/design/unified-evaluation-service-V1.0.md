# 统一评测服务架构设计

**版本**: V1.0  
**日期**: 2026-07-15  
**状态**: ✅ 已实现（待测试）  
**作者**: AI Assistant

---

## 一、概述

### 1.1 设计目标

统一评测服务（`UnifiedEvaluationService`）是 VidLang 语言学习应用的核心评测框架，对标现有的 `UnifiedTtsService` 和 `UnifiedTranslationService`，提供统一的评测入口。

**核心设计原则**：
- **统一入口**：一个 `evaluate()` 方法搞定所有评测场景
- **一致调用方式**：不管底层是原生 STT 还是声通，前端调用方式完全相同
- **一致返回类型**：统一返回 `UnifiedEvaluationResult`，前端根据 `hasDetail` 区分展示深度
- **自动分流**：根据 `SubscriptionMode` 自动选择底层引擎
- **扩展性**：未来新增评测引擎只需添加新的 case 分支

### 1.2 适用场景

| 场景 | Free 模式 | Premium 模式 |
|------|-----------|--------------|
| 视频跟读 | ✅ 基础识别 + 相似度评分 | ✅ 详细评分 + 单词级分析 |
| 音频跟读 | ✅ 实时 STT 识别 | ✅ 离线音频文件评测 |
| 单词朗读 | ❌ 不支持 | ✅ 音素级评分 |
| 句子评测 | ❌ 不支持 | ✅ 多维度评分 |
| 段落朗读 | ❌ 不支持 | ✅ 句子级 + 整体评分 |

---

## 二、架构设计

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        前端 UI 层                           │
│                                                             │
│  PronunciationEvaluationModal                                │
│  ├─> 调用 UnifiedEvaluationService.evaluate()               │
│  └─> 根据 hasDetail 决定 UI 展示深度                        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              UnifiedEvaluationService (单例)                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              evaluate() 统一入口                     │   │
│  │                                                     │   │
│  │  参数:                                              │   │
│  │  - refText: String (参考文本)                        │   │
│  │  - mode: SubscriptionMode (free/premium)            │   │
│  │  - audioBytes?: Uint8List (内存音频)                 │   │
│  │  - audioPath?: String (音频文件路径)                 │   │
│  │                                                     │   │
│  │  返回: UnifiedEvaluationResult                       │   │
│  └─────────────────────┬───────────────────────────────┘   │
│                        │                                   │
│           ┌────────────┴────────────┐                      │
│           ▼                         ▼                      │
│    ┌──────────────┐         ┌──────────────┐               │
│    │  Free 模式    │         │ Premium 模式  │               │
│    │              │         │              │               │
│    │ 原生 STT     │         │ 声通评测引擎  │               │
│    │ (iOS)        │         │ (HTTP)       │               │
│    └──────┬───────┘         └──────┬───────┘               │
│           │                        │                         │
│           ▼                        ▼                         │
│    ┌──────────────┐         ┌──────────────┐               │
│    │ 基础功能      │         │ 高级功能      │               │
│    │              │         │              │               │
│    │ • 语音识别    │         │ • 多维度评分  │               │
│    │ • 文本匹配    │         │ • 流利度分析  │               │
│    │ • 相似度分数  │         │ • 准确度评估  │               │
│    │              │         │ • 完整度检测  │               │
│    │ ⚠️ 限制:     │         │ • 单词级评分  │               │
│    │ 仅实时跟读    │         │ • 音素级分析  │               │
│    └──────────────┘         └──────────────┘               │
│                        │                                   │
│                        ▼                                   │
│           ┌──────────────────────────────┐                │
│           │   UnifiedEvaluationResult    │                │
│           │                              │                │
│           │ • success: bool              │                │
│           │ • error / code               │                │
│           │ • overallScore (0-100)       │                │
│           │ • isPremium: bool            │                │
│           │ • detail? (详细评分)          │                │
│           │   ├─ fluency                 │                │
│           │   ├─ accuracy                │                │
│           │   ├─ completeness            │                │
│           │   ├─ pronunciation           │                │
│           │   └─ wordEvaluations[]       │                │
│           └──────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 模式分流逻辑

```dart
Future<UnifiedEvaluationResult> evaluate({
  required String refText,
  required SubscriptionMode mode,
  Uint8List? audioBytes,
  String? audioPath,
}) async {
  switch (mode) {
    case SubscriptionMode.free:
      return await _evaluateFree(...);  // 原生 STT
    
    case SubscriptionMode.premium:
      return await _evaluatePremium(...);  // 声通评测
  }
}
```

---

## 三、核心类设计

### 3.1 UnifiedEvaluationService（单例）

**位置**: `lib/services/evaluation/unified_evaluation_service.dart`

**职责**：
- 提供统一的评测入口 `evaluate()`
- 根据 `SubscriptionMode` 自动选择底层引擎
- 解析和转换不同引擎的返回结果为统一格式
- 管理 `ShengtongHttpEvaluator` 的生命周期

**关键方法**：

| 方法 | 类型 | 说明 |
|------|------|------|
| `instance` | Getter | 获取单例实例 |
| `evaluate()` | 异步方法 | 统一评测入口 |
| `processNativeSttResult()` | 静态方法 | 处理原生 STT 结果（Free 模式专用） |
| `dispose()` | 方法 | 释放资源 |

### 3.2 UnifiedEvaluationResult（结果模型）

**职责**：
- 封装统一的评测结果
- 提供便捷的属性访问（`gradeLabel`, `hasDetail`）
- 区分成功/错误状态

**属性说明**：

```dart
class UnifiedEvaluationResult {
  final bool success;           // 是否成功
  final String? error;          // 错误信息（失败时）
  final String? code;           // 错误码（失败时）
  final String referenceText;   // 参考文本
  final String recognizedText;  // 识别文本
  final double overallScore;    // 总分 (0-100)
  final bool isPremium;         // 是否为 Premium 模式
  final EvaluationDetail? detail; // 详细评分（Premium 专属）
  
  // 便捷属性
  String get gradeLabel;        // 评级标签（优秀/良好/一般/较差/需改进）
  bool get hasDetail;           // 是否有详细评分
}
```

**错误码定义**：

| 错误码 | 说明 | 触发场景 |
|--------|------|----------|
| `EMPTY_TEXT` | 参考文本为空 | refText 为空字符串 |
| `NOT_SUPPORTED` | 设备不支持 | 非 iOS 设备或无 Speech Framework |
| `REALTIME_ONLY` | 仅支持实时模式 | Free 模式传入离线音频 |
| `USE_NATIVE_STT_STREAM` | 需使用原生 STT 流 | Free 模式实时跟读提示 |
| `SERVICE_NOT_CONFIGURED` | 服务未配置 | 声通 AppKey/Secret 未设置 |
| `FILE_NOT_FOUND` | 音频文件不存在 | audioPath 指向不存在的文件 |
| `NO_AUDIO_INPUT` | 无音频输入 | audioBytes 和 audioPath 都为 null |
| `STT_ERROR` | STT 识别失败 | 原生 STT 返回错误 |
| `EVALUATION_ERROR` | 评测异常 | 其他未预期的异常 |

### 3.3 EvaluationDetail（详细评分）

**适用范围**：仅 Premium 模式有值，Free 模式为 `null`

**属性说明**：

```dart
class EvaluationDetail {
  final double? fluency;          // 流利度 (0-100)
  final double? accuracy;         // 准确度 (0-100)
  final double? completeness;     // 完整度 (0-100)
  final double? pronunciation;    // 发音得分 (0-100)
  final List<WordEvaluation> wordEvaluations; // 单词级评分列表
  final Map<String, dynamic>? rawResult;      // 原始结果（调试用）
  
  // 便捷方法
  bool get hasWordEvaluations;    // 是否有单词级评分
  List<WordEvaluation> get weakWords;      // 需重点练习的单词 (<70分)
  List<WordEvaluation> get excellentWords; // 表现优秀的单词 (>=90分)
}
```

---

## 四、使用示例

### 4.1 基础用法（推荐）

```dart
import 'package:vidlang/services/evaluation/unified_evaluation_service.dart';
import 'package:vidlang/providers/subscription_provider.dart';

// 1. 获取订阅模式
final subscriptionState = ref.watch(subscriptionProvider);
final mode = subscriptionState.mode;

// 2. 调用统一评测
final result = await UnifiedEvaluationService.instance.evaluate(
  refText: 'Hello world, how are you today?',
  mode: mode,
  audioBytes: recordedAudioBytes,  // 或 audioPath: '/path/to/audio.wav'
);

// 3. 处理结果
if (result.success) {
  print('总分: ${result.overallScore.toInt()}%');
  print('评级: ${result.gradeLabel}');
  
  if (result.hasDetail) {
    // Premium 模式：显示详细评分
    print('流利度: ${result.detail?.fluency}');
    print('准确度: ${result.detail?.accuracy}');
    
    // 显示需要重点练习的单词
    for (final word in result.detail!.weakWords) {
      print('需练习: ${word.word} (${word.score.toInt()}%)');
    }
  } else {
    // Free 模式：仅显示基础分数
    print('识别文本: ${result.recognizedText}');
  }
} else {
  print('评测失败: ${result.error} (代码: ${result.code})');
}
```

### 4.2 Free 模式实时跟读

```dart
import 'package:vidlang/services/native/ios_native_features.dart';
import 'package:vidlang/services/evaluation/unified_evaluation_service.dart';

// 1. 开始原生 STT 录音
await IosNativeFeatures.startSpeechRecognition();

// 2. 监听识别结果
IosNativeFeatures.onSpeechResult.listen((sttResult) {
  if (sttResult.isFinal) {
    // 3. 将 STT 结果转换为统一格式
    final evalResult = UnifiedEvaluationService.processNativeSttResult(
      refText: 'Hello world',
      sttResult: sttResult,
    );
    
    // 4. 更新 UI
    if (evalResult.success) {
      showScore(evalResult.overallScore);
    }
  }
});

// 5. 停止录音
await IosNativeFeatures.stopSpeechRecognition();
```

### 4.3 Premium 模式离线评测

```dart
import 'dart:io';
import 'package:vidlang/services/evaluation/unified_evaluation_service.dart';

// 从文件系统读取音频文件
final audioFile = File('/path/to/recording.wav');
final audioBytes = await audioFile.readAsBytes();

// 调用 Premium 评测
final result = await UnifiedEvaluationService.instance.evaluate(
  refText: 'The quick brown fox jumps over the lazy dog',
  mode: SubscriptionMode.premium,
  audioBytes: audioBytes,
);

// 显示详细评分面板
if (result.hasDetail) {
  showDetailPanel(
    overallScore: result.overallScore,
    fluency: result.detail!.fluency!,
    accuracy: result.detail!.accuracy!,
    words: result.detail!.wordEvaluations,
  );
}
```

---

## 五、前后端交互流程

### 5.1 Premium 模式完整流程

```
用户点击"开始录音"
       │
       ▼
┌─────────────────┐
│  录音组件录制音频  │  ← 使用 record/audio 库
│  生成 PCM/WAV    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  UnifiedEvaluationService.evaluate()    │
│                                         │
│  1. 检查 refText 非空                   │
│  2. 判断 mode == premium                │
│  3. 获取 ShengtongHttpEvaluator 实例     │
│  4. 调用 evaluator.evaluateBytes()      │
│     ┌──────────────────────────────┐    │
│     │ HTTP POST → 声通 API         │    │
│     │ 参数:                        │    │
│     │ - coreType: sent.eval        │    │
│     │ - refText: "..."             │    │
│     │ - audioData: [bytes]         │    │
│     └──────────────────────────────┘    │
│  5. 解析返回 JSON                      │
│  6. 构建 UnifiedEvaluationResult       │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  返回 UnifiedEvaluationResult           │
│                                         │
│  {                                      │
│    success: true,                       │
│    referenceText: "...",                │
│    recognizedText: "...",               │
│    overallScore: 85.5,                  │
│    isPremium: true,                     │
│    detail: {                            │
│      fluency: 88.0,                     │
│      accuracy: 82.5,                    │
│      completeness: 90.0,                │
│      pronunciation: 85.0,               │
│      wordEvaluations: [                 │
│        { word: "Hello", score: 92 },    │
│        { word: "world", score: 78 },    │
│        ...                              │
│      ]                                  │
│    }                                    │
│  }                                      │
└─────────────────────────────────────────┘
                 │
                 ▼
         前端根据 hasDetail 决定 UI 展示深度
```

### 5.2 Free 模式流程

```
用户点击"开始录音"
       │
       ▼
┌─────────────────────────────────────────┐
│  UnifiedEvaluationService.evaluate()    │
│                                         │
│  1. 检查 refText 非空                   │
│  2. 判断 mode == free                   │
│  3. 检查 IosNativeFeatures 可用性       │
│  4. 判断是否有离线音频输入               │
│     ├── 有 → 返回 REALTIME_ONLY 错误     │
│     └── 无 → 返回 USE_NATIVE_STT_STREAM │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  前端处理 USE_NATIVE_STT_STREAM 提示     │
│                                         │
│  1. 调用 IosNativeFeatures              │
│     .startSpeechRecognition()           │
│  2. 监听 onSpeechResult Stream          │
│  3. 收到最终结果后调用                  │
│     UnifiedEvaluationService            │
│     .processNativeSttResult()           │
│  4. 获取基础评分结果                     │
└─────────────────────────────────────────┘
```

---

## 六、扩展指南

### 6.1 新增评测引擎

如果未来需要支持新的评测引擎（如百度、讯飞），只需在 `_evaluatePremium()` 中添加新的分支：

```dart
Future<UnifiedEvaluationResult> _evaluatePremium({...}) async {
  // 根据配置选择引擎
  final engineType = AppKeysService.instance.evaluationEngine;
  
  Map<String, dynamic> rawResult;
  
  switch (engineType) {
    case 'shengtong':
      rawResult = await _evaluateWithShengtong(...);
      break;
    case 'baidu':
      rawResult = await _evaluateWithBaidu(...);  // 新增
      break;
    case 'xunfei':
      rawResult = await _evaluateWithXunfei(...);  // 新增
      break;
    default:
      throw UnsupportedError('不支持的评测引擎: $engineType');
  }
  
  // 统一解析为 UnifiedEvaluationResult
  return _parseRawResult(rawResult, refText);
}
```

### 6.2 新增评分维度

如果声通或其他引擎返回新的评分维度，只需扩展 `EvaluationDetail` 类：

```dart
class EvaluationDetail {
  // 现有维度...
  final double? fluency;
  final double? accuracy;
  final double? completeness;
  final double? pronunciation;
  
  // 新增维度...
  final double? rhythm;        // 韵律度（新增）
  final double? intonation;    // 语调（新增）
  final double? stress;        // 重音（新增）
  
  // 更新解析逻辑...
}
```

---

## 七、测试建议

### 7.1 单元测试

```dart
// 测试文本相似度算法
test('文本相似度计算', () {
  final similarity = UnifiedEvaluationService._calculateTextSimilarityStatic(
    'hello world', 
    'hello world'
  );
  expect(similarity, equals(100.0));
});

// 测试结果模型构建
test('UnifiedEvaluationResult 成功结果', () {
  final result = UnifiedEvaluationResult.success(
    referenceText: 'Test',
    recognizedText: 'Test',
    overallScore: 85.5,
    isPremium: true,
  );
  
  expect(result.success, isTrue);
  expect(result.gradeLabel, equals('良好'));
  expect(result.hasDetail, isFalse);
});
```

### 7.2 集成测试

```dart
// 测试 Free 模式 STT 集成
testWidgets('Free 模式实时跟读流程', (tester) async {
  // 1. 打开评测 Modal
  // 2. 点击录音按钮
  // 3. 模拟语音输入
  // 4. 验证收到 STT 结果
  // 5. 验证 processNativeSttResult 输出
});

// 测试 Premium 模式声通集成
test('Premium 模式离线评测流程', (tester) async {
  // 1. 准备测试音频文件
  // 2. 调用 evaluate()
  // 3. Mock 声通 API 返回
  // 4. 验证 UnifiedEvaluationResult 结构
  // 5. 验证 detail 包含所有预期字段
});
```

---

## 八、注意事项

### 8.1 性能优化

- **懒加载**：`ShengtongHttpEvaluator` 采用懒加载模式，首次调用时才初始化
- **缓存策略**：考虑缓存最近的评测结果，避免重复请求
- **音频压缩**：上传前对音频进行压缩（16kHz mono WAV），减少网络传输时间

### 8.2 错误处理

- **网络超时**：声通 API 调用应设置合理的超时时间（建议 10-15 秒）
- **重试机制**：对于临时性错误（网络波动），可实现自动重试（最多 3 次）
- **降级方案**：Premium 模式下如果声通服务不可用，可降级到 Free 模式的 STT 识别

### 8.3 安全性

- **API Key 保护**：声通的 AppKey 和 SecretKey 应存储在安全存储中（flutter_secure_storage）
- **音频数据加密**：上传的音频数据应使用 HTTPS 加密传输
- **用户隐私**：评测完成后及时清理本地缓存的音频文件

---

## 九、相关文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 服务架构总览 | `docs/reference/services-architecture.md` | 所有服务的架构设计 |
| 评测模型定义 | `lib/models/evaluation_models.dart` | 旧版评测模型（待迁移） |
| 声通评测器 | `lib/services/evaluation/shengtong_http_evaluator.dart` | 声通 HTTP 评测实现 |
| 原生功能 | `lib/services/native/ios_native_features.dart` | iOS 原生 STT 功能 |
| 订阅状态管理 | `lib/providers/subscription_provider.dart` | SubscriptionMode 定义 |

---

## 十、版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| V1.0 | 2026-07-15 | 初始版本，实现统一评测服务框架 | AI Assistant |

---

**文档结束**
