# 跟读评测功能实施文档

## 📋 概述

本文档详细说明VidLang应用中跟读评测功能的实施细节和使用方法。评测系统支持四种模式：免费STT识别、单词精听、句子评测和段落流畅度评测。

## 🏗️ 架构设计

### 核心组件结构

```
lib/
├── models/
│   └── evaluation_models.dart          # 数据模型定义
├── services/
│   └── evaluation_service.dart         # 评测服务逻辑
└── widgets/
    ├── pronunciation_evaluation_modal.dart     # 主弹窗组件
    ├── evaluation_content_widgets.dart        # 内容显示组件
    └── evaluation_demo.dart                   # 演示组件
└── views/
    ├── evaluation_test_page.dart               # 测试页面
```

### 数据流架构

```
用户交互
    ↓
showPronunciationEvaluation() → PronunciationEvaluationModal
    ↓
EvaluationModeDetector.detectMode() → 自动选择最佳评测模式
    ↓
对应ContentWidget显示界面
    ↓
EvaluationService执行评测
    ↓
EvaluationResult返回结果
    ↓
UI更新显示得分和分析
```

## 🎯 评测模式详解

### 1. 免费STT模式 (EvaluationMode.freeSTT)

**适用场景**: 基础语音识别练习，无需付费

**功能特点**:
- 原始文本与识别文本对比
- 单词级颜色区分（🟢正确，🔴错误）
- 支持多行滚动显示长文本
- 实时颜色反馈

**使用示例**:
```dart
showPronunciationEvaluation(
  context,
  text: 'This is a simple test sentence.',
  mode: EvaluationMode.freeSTT,
  onComplete: (result) {
    print('评测得分: ${result.overallScore}%');
  },
);
```

### 2. 单词精听模式 (EvaluationMode.word)

**适用场景**: 单个单词的精确发音练习

**功能特点**:
- 音素级分解显示
- 每个音素独立评分
- 重音位置分析
- 发音建议反馈

**文本要求**: 单个单词，无空格，长度≤20字符

### 3. 句子评测模式 (EvaluationMode.sentence)

**适用场景**: 完整句子的综合发音评测

**功能特点**:
- 流利度、准确度、完整度三维度评分
- 逐词分析
- 可展开查看详细报告
- 上下文相关的发音建议

**文本要求**: 长度≤100字符

### 4. 段落流畅度模式 (EvaluationMode.paragraph)

**适用场景**: 长文本的整体流畅度练习

**功能特点**:
- 连贯性分析
- 语速稳定性评估
- 长句处理能力
- 整体韵律评价

**文本要求**: 长度>100字符

## 🔧 集成方法

### 1. 在播放器中集成

```dart
class PlayerPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 视频播放区域
        VideoPlayer(),
        
        // 字幕显示区域
        SubtitleWidget(
          text: currentSubtitle,
          onTap: () {
            // 显示跟读评测
            showPronunciationEvaluation(
              context,
              text: currentSubtitle,
            );
          },
        ),
        
        // 跟读评测按钮
        ElevatedButton(
          onPressed: () {
            showPronunciationEvaluation(
              context,
              text: currentSubtitle,
            );
          },
          child: Text('开始跟读评测'),
        ),
      ],
    );
  }
}
```

### 2. 在任意页面使用

```dart
// 简单调用
showPronunciationEvaluation(context, text: 'Hello World');

// 完整配置
showPronunciationEvaluation(
  context,
  text: 'This is a longer sentence for evaluation.',
  mode: EvaluationMode.sentence, // 可选，不传则自动检测
  onComplete: (result) {
    // 处理评测结果
    _showResultMessage(result);
  },
);
```

### 3. 测试和演示

```dart
// 导航到测试页面
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EvaluationTestPage(),
  ),
);

// 或者在应用中使用演示组件
showDialog(
  context: context,
  builder: (context) => EvaluationDemo(),
);
```

## 📊 评测结果显示

### 评分色彩系统

- **🟢 深绿色 (90-100%)**: 优秀发音
- **🟢 绿色 (80-89%)**: 良好发音
- **🟡 橙色 (70-79%)**: 一般水平
- **🔴 红色 (60-69%)**: 需要改进
- **🔴 深红色 (<60%)**: 严重错误

### 界面布局规范

```
┌─────────────────────────────────────────┐
│ 📊 跟读评测                          ✕ │  ← 固定高度: 56dp
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐    │  ← 可变高度区域
│  │  内容依据评测模式变化             │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
├─────────────────────────────────────────┤
│              🎯 85%                      │  ← 固定高度: 80dp
│            ████████░░                   │
├─────────────────────────────────────────┤
│ 🔊 ────────●──────── 🎤                 │
│ 原音音量   60%     录音                 │  ← 固定高度: 120dp
│                                         │
│ ⏸️   🔄   ▶️   💾   ⚡                  │
│停止 重录 回放 保存 详情                │
└─────────────────────────────────────────┘
```

## 🎨 视觉设计规范

### 主题适配

评测组件自动适配应用的当前主题：

```dart
// 自动适配当前主题
showPronunciationEvaluation(context, text: text);

// 或指定特定主题
showDialog(
  context: context,
  builder: (context) => Theme(
    data: myCustomTheme,
    child: PronunciationEvaluationModal(...),
  ),
);
```

### 暗色模式支持

```dart
// 组件自动检测并适配暗色模式
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  return Container(
    color: isDark ? Colors.grey.shade900 : Colors.white,
    // ...
  );
}
```

## 🔄 状态管理

### 评测服务状态

```dart
class EvaluationService {
  // 录音状态流
  Stream<bool> get recordingStream;
  
  // 评测结果流  
  Stream<EvaluationResult> get resultStream;
  
  // 开始录音
  Future<void> startRecording();
  
  // 停止录音
  Future<String?> stopRecording();
  
  // 执行评测
  Future<EvaluationResult> evaluateRecording({
    required String referenceText,
    required EvaluationMode mode,
    String? audioPath,
  });
  
  // 获取历史记录
  Future<List<EvaluationResult>> getEvaluationHistory();
  
  // 获取统计数据
  Future<EvaluationStats> getEvaluationStats();
}
```

### 实时状态更新

```dart
// 监听录音状态
evaluationService.recordingStream.listen((isRecording) {
  setState(() {
    _isRecording = isRecording;
  });
});

// 监听评测结果
evaluationService.resultStream.listen((result) {
  setState(() {
    _currentResult = result;
  });
});
```

## 📱 响应式设计

### 屏幕尺寸适配

```dart
// 手机横屏
constraints: BoxConstraints(
  maxHeight: screenHeight * 0.9,
  maxWidth: screenWidth * 0.6,
);

// 手机竖屏  
constraints: BoxConstraints(
  maxHeight: screenHeight * 0.75,
  maxWidth: screenWidth * 0.92,
);

// 平板设备
constraints: BoxConstraints(
  maxHeight: screenHeight * 0.6,
  maxWidth: screenWidth * 0.5,
);
```

### 文本长度自适应

- **短文本 (<20字)**: 单行水平布局
- **中等文本 (20-50字)**: 双行显示
- **长文本 (>50字)**: 三行显示+滚动支持

## 🚀 性能优化

### 内存管理

```dart
// 及时释放资源
@override
void dispose() {
  evaluationService.dispose();
  recordingController.close();
  resultController.close();
  super.dispose();
}
```

### 异步处理

```dart
// 非阻塞UI更新
void onRecordingComplete() async {
  final result = await evaluationService.evaluateRecording(...);
  
  // 使用setState更新UI
  if (mounted) {
    setState(() {
      _currentResult = result;
    });
  }
}
```

## 🧪 测试指南

### 单元测试

```dart
void main() {
  group('Evaluation Tests', () {
    test('模式检测器正确识别文本类型', () {
      expect(EvaluationModeDetector.detectMode('hello'), 
             EvaluationMode.word);
      expect(EvaluationModeDetector.detectMode('hello world'), 
             EvaluationMode.sentence);
    });
    
    test('评测服务生成正确结果', () async {
      final service = EvaluationService();
      final result = await service.evaluateRecording(
        referenceText: 'test',
        mode: EvaluationMode.word,
      );
      
      expect(result.score, greaterThan(0));
    });
  });
}
```

### 集成测试

```dart
void main() {
  testWidgets('评测弹窗正常显示', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            showPronunciationEvaluation(context, text: 'hello');
          },
          child: Text('Show Evaluation'),
        ),
      ),
    ));

    await tester.tap(find.text('Show Evaluation'));
    await tester.pumpAndSettle();

    expect(find.text('跟读评测'), findsOneWidget);
  });
}
```

## 📝 后续优化建议

### 1. 音频处理优化
- [ ] 实现真实的录音功能
- [ ] 集成声通评测API
- [ ] 添加音频质量检查

### 2. UI/UX 改进
- [ ] 添加更多动画效果
- [ ] 优化长文本滚动体验  
- [ ] 添加发音建议气泡

### 3. 功能扩展
- [ ] 支持多语言评测
- [ ] 添加发音对比功能
- [ ] 实现云端数据同步

### 4. 性能监控
- [ ] 添加评测性能指标
- [ ] 优化内存使用
- [ ] 添加错误监控

## 🤝 贡献指南

### 代码风格

```dart
// 使用有意义的变量名
final EvaluationResult pronunciationResult;

// 添加详细的注释
/// 计算单词发音得分
/// [word] - 要评测的单词
/// [audioPath] - 音频文件路径
/// 返回: [WordEvaluation] 包含详细评分
Future<WordEvaluation> evaluateWord(String word, String audioPath);

// 使用const构造函数
const PronunciationEvaluationModal({
  super.key,
  required this.referenceText,
  required this.mode,
});
```

### 提交规范

```
feat(evaluation): 添加单词精听功能
fix(evaluation): 修复长文本滚动问题
docs(evaluation): 更新实施文档
```

## ❓ 常见问题解答

**Q: 如何在现有页面集成评测功能？**
A: 只需调用 `showPronunciationEvaluation(context, text: yourText)` 即可。

**Q: 评测失败如何处理？**
A: 系统会自动捕获异常，显示错误提示，并提供重试选项。

**Q: 如何自定义主题？**
A: 使用Theme组件包裹PronunciationEvaluationModal即可。

**Q: 评测数据如何保存？**
A: 评测结果会自动保存在本地数据库，付费用户的详细数据会上传到云端。

## 🎊 完成状态

✅ 核心架构实现完成
✅ 四种评测模式支持
✅ 响应式UI设计
✅ 主题适配系统
✅ 状态管理集成
✅ 测试用例覆盖

📋 待完善:
- 音频录制实现
- 声通API集成
- 云端同步功能
- 性能监控系统