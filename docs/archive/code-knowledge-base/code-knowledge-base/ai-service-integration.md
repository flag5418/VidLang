# AI 服务集成知识库

> **版本**: v1.0.0
> **最后更新**: 2026-07-12
> **状态**: ✅ 已启用 - 双模式 AI 服务（云端代理 + 本地模型）
> **核心文件**: `lib/services/ai_service.dart`

---

## 📋 目录

1. [核心原则](#核心原则)
2. [架构概览](#架构概览)
3. [双模式设计](#双模式设计)
4. [AiService API 完整参考](#aiservice-api-完整参考)
5. [rule_code 功能详解](#rule_code-功能详解)
6. [云端模式（Edge Functions）](#云端模式edge-functions)
7. [本地模式（Local AI）](#本地模式local-ai)
8. [计费与缓存策略](#计费与缓存策略)
9. [WordDetail 模型](#worddetail-模型)
10. [最佳实践](#最佳实践)
11. [常见问题排查](#常见问题排查)

---

## 核心原则

### ⚠️ 强制规范

> **所有 AI 功能调用必须通过 AiService 统一入口**，禁止直接调用第三方 API 或 Edge Function。

**双模式架构**:
- ✅ **云端模式**（默认）：通过 Supabase Edge Function (`ai-proxy`) 代理调用 DeepSeek 等大模型
- ✅ **本地模式**（可选）：使用 iOS 系统翻译 (MLTranslation) / ONNX Runtime 本地模型
- ✅ **自动降级**：云端失败时自动切换到本地模型（如可用）

**禁止行为**:
- ❌ 直接调用 DeepSeek API、OpenAI API 等
- ❌ 绕过 AiService 直接调用 `client.functions.invoke`
- ❌ 在 UI 层硬编码 AI 模型参数（prompt、temperature 等）
- ❌ 忽略余额检查继续调用付费接口

---

## 架构概览

### 整体架构图

```
┌─────────────────────────────────────────────────────┐
│                  VidLang App (Flutter)               │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │              AiService (统一入口)             │    │
│  │                                             │    │
│  │  callAiProxy(ruleCode, scene, word, params)  │    │
│  └──────────────────┬──────────────────────────┘    │
│                     │                                │
│         ┌───────────┴───────────┐                    │
│         ▼                       ▼                    │
│  ┌──────────────┐      ┌──────────────────┐         │
│  │ Cloud Mode   │      │ Local Mode       │         │
│  │ (默认)       │      │ (可选/降级)       │         │
│  └──────┬───────┘      └────┬─────────────┘         │
│         │                   │                       │
│  ┌──────▼───────────────────▼──────────────────┐    │
│  │           Supabase Client SDK                │    │
│  └─────────────────────┬────────────────────────┘    │
└────────────────────────┼──────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌────────────┐ ┌────────────┐ ┌────────────┐
   │ ai-proxy   │ │ iOS System │ │ ONNX      │
   │ Edge Func  │ │ MLTranslation│ Runtime   │
   │ (DeepSeek) │ │ (iOS 17.4+)│ │ (本地模型) │
   └────────────┘ └────────────┘ └────────────┘
```

### 调用流程

```
用户触发查词/翻译
       │
       ▼
  AiService.callAiProxy()
       │
       ├── preferLocal == true 且本地可用？
       │       │
       │      YES → LocalAiService → iOS MLTranslation / ONNX
       │
       └── NO （默认）→ AuthService.ensureActiveSession()
                           │
                    Supabase.client.functions.invoke('ai-proxy')
                           │
                      ┌────┴────┐
                      ▼         ▼
                  成功        失败
                      │         │
                      ▼         ▼
              WordDetail    余额不足？→ WordDetail.error(isInsufficientBalance: true)
              .fromAiResult()     │
                                  NO → 尝试本地降级？→ 成功则返回，失败则 error
```

---

## 双模式设计

### 模式选择策略

| 场景 | 推荐模式 | 说明 |
|------|----------|------|
| 单词查词（字幕中点击） | 云端（默认） | 需要详细释义、音标、例句 |
| 句子翻译（字幕批量） | 本地优先 | 大量文本，降低成本 |
| 离线环境 | 本地强制 | 无网络时自动降级 |
| VIP 用户 | 云端 | 高质量结果，不计成本 |
| 免费用户 | 本地优先 | 节省额度 |
| 发音评分 | 云端唯一 | 需要专业语音模型 |

### 切换方式

```dart
// 方式 1：调用时指定（推荐）
final result = await AiService.callAiProxy(
  ruleCode: 'ai_translate',
  word: text,
  preferLocal: true,  // ✅ 强制使用本地模型
);

// 方式 2：全局设置（影响后续所有调用）
// 通过 Riverpod Provider 控制
ref.read(aiModeProvider.notifier).state = AiMode.local;
```

---

## AiService API 完整参考

### 核心方法

```dart
class AiService {
  /// 统一 AI 调用入口
  static Future<WordDetail> callAiProxy({
    required String ruleCode,     // 功能规则码
    required String scene,        // 使用场景
    required String entry,        // 词条类型
    required String word,         // 待处理文本
    String? sourceType,          // 来源类型（video/article/conversation）
    String? sourceCode,          // 来源标识
    Map<String, dynamic> params, // 业务参数
    Map<String, dynamic>? billing, // 计费信息
    bool preferLocal = false,    // 是否优先本地模型
  })
```

#### 参数详解

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `ruleCode` | String | ✅ | 功能规则码（见下文列表） |
| `scene` | String | ✅ | 使用场景（subtitle/article/conversation/wordbook） |
| `entry` | String | ✅ | 词条类型（word/sentence/paragraph） |
| `word` | String | ✅ | 待处理的文本内容 |
| `sourceType` | String | ❌ | 来源类型（用于统计和计费） |
| `sourceCode` | String | ❌ | 来源标识（video_123、article_456） |
| `params` | Map | ❌ | 业务参数（因 ruleCode 而异） |
| `billing` | Map | ❌ | 显式指定计费中心 |
| `preferLocal` | bool | ❌ | 是否优先本地模型（默认 false） |

#### 返回值

```dart
/// 成功
WordDetail(
  word: 'hello',
  translation: '你好',
  phonetic: '/həˈləʊ/',
  partOfSpeech: 'int.',
  definition: '用于问候或引起注意',
  examples: ['Hello, how are you?'],
  costCny: 0.01,
  balanceAfter: 9.99,
)

/// 余额不足
WordDetail.error(
  'hello',
  '余额不足',
  isInsufficientBalance: true,
  requiredCny: 0.50,
  balanceCny: 0.00,
)

/// 其他错误
WordDetail.error(
  'hello',
  'AI 服务调用失败: network error',
)
```

### 便捷方法（封装层）

```dart
// 1️⃣ 单词查词（字幕点击）
static Future<WordDetail> lookupWord(String word, {String? sourceCode}) async {
  return callAiProxy(
    ruleCode: 'ai_word_lookup',
    scene: 'subtitle',
    entry: 'word',
    word: word,
    sourceType: 'video',
    sourceCode: sourceCode,
  );
}

// 2️⃣ 句子翻译（字幕批量）
static Future<WordDetail> translateSentence(String sentence) async {
  return callAiProxy(
    ruleCode: 'ai_translate',
    scene: 'subtitle',
    entry: 'sentence',
    word: sentence,
    preferLocal: true,  // 批量翻译优先本地
  );
}

// 3️⃣ 文章翻译
static Future<WordDetail> translateArticle(String text) async {
  return callAiProxy(
    ruleCode: 'ai_translate',
    scene: 'article',
    entry: 'paragraph',
    word: text,
  );
}

// 4️⃣ 会话翻译
static Future<WordDetail> translateConversation(String text) async {
  return callAiProxy(
    ruleCode: 'ai_translate_conversation',
    scene: 'conversation',
    entry: 'sentence',
    word: text,
  );
}
```

---

## rule_code 功能详解

### 完整列表

| rule_code | 功能 | 输入 | 输出 | 计费 | 支持本地 |
|-----------|------|------|------|------|----------|
| `ai_word_lookup` | 单词查词 | 单词 | 释义+音标+例句 | ¥0.01/次 | ⚠️ 有限 |
| `ai_translate` | 通用翻译 | 句子/段落 | 中文翻译 | ¥0.02/次 | ✅ 支持 |
| `ai_translate_conversation` | 会话翻译 | 对话文本 | 自然口语翻译 | ¥0.02/次 | ✅ 支持 |
| `ai_definition` | 单词释义 | 单词 | 简明释义 | ¥0.005/次 | ✅ 支持 |
| `ai_tts` | 文本转语音 | 文本 | 音频文件 URL | ¥0.03/次 | ✅ 支持 |
| `ai_pronunciation_score` | 发音评分 | 音频数据 | 分数(0-100)+反馈 | ¥0.05/次 | ❌ 仅云端 |
| `ai_grammar_check` | 语法检查 | 英文文本 | 错误标注+修改建议 | ¥0.04/次 | ❌ 仅云端 |

### 详细说明

#### 1. ai_word_lookup（单词查词）⭐⭐⭐

**最常用的功能**，用于字幕点击查词。

```dart
final detail = await AiService.callAiProxy(
  ruleCode: 'ai_word_lookup',
  scene: 'subtitle',          // 使用场景
  entry: 'word',             // 词条类型
  word: 'ephemeral',         // 查询的单词
  sourceType: 'video',       // 来源类型
  sourceCode: 'video_123',   // 视频 ID
);

print(detail.translation);    // '短暂的'
print(detail.phonetic);       // '/ɪˈfem(ə)rəl/'
print(detail.partOfSpeech);   // 'adj.'
print(detail.definition);     // 'lasting for a very short time'
print(detail.examples);       // ['fame is ephemeral']
print(detail.costCny);        // 0.01
```

**返回的 WordDetail 结构**:
```dart
class WordDetail {
  final String word;              // 原词
  final String? translation;      // 中文释义
  final String? phonetic;         // 国际音标
  final String? partOfSpeech;     // 词性
  final String? definition;       // 详细定义
  final List<String>? examples;   // 例句
  final double? costCny;          // 本次费用
  final double? balanceAfter;     // 余额
  final bool isError;             // 是否错误
  final String? errorMessage;     // 错误信息
  final bool isInsufficientBalance; // 是否余额不足
  final double? requiredCny;      // 所需金额
}
```

#### 2. ai_translate（通用翻译）

用于字幕句子翻译、文章段落翻译。

```dart
// 字幕单句翻译
final result = await AiService.callAiProxy(
  ruleCode: 'ai_translate',
  scene: 'subtitle',
  entry: 'sentence',
  word: 'The quick brown fox jumps over the lazy dog.',
);

print(result.translation); // '敏捷的棕色狐狸跳过了懒狗'
```

#### 3. ai_tts（文本转语音）

生成单词或句子的发音音频。

```dart
final audioResult = await AiService.callAiProxy(
  ruleCode: 'ai_tts',
  scene: 'wordbook',
  entry: 'word',
  word: 'hello',
  params: {
    'voice': 'en-US',  // 音色：美式英语
    'speed': 1.0,      // 语速
  },
);

// 返回 audioUrl 或 base64 编码的音频数据
final audioUrl = audioResult.audioUrl;
```

#### 4. ai_pronunciation_score（发音评分）

跟读练习时的发音质量评估。

```dart
final scoreResult = await AiService.callAiProxy(
  ruleCode: 'ai_pronunciation_score',
  scene: 'follow_mode',
  entry: 'sentence',
  word: targetSentence,
  params: {
    'user_audio_path': recordedAudioPath,  // 用户录音文件路径
    'reference_text': targetSentence,       // 原文
  },
);

print(scoreResult.pronunciationScore); // 85.5 (0-100)
print(scoreResult.feedback);            // 'Your pronunciation of "th" needs improvement'
```

---

## 云端模式（Edge Functions）

### ai-proxy 函数详情

**函数名**: `ai-proxy`
**运行时**: Deno (Supabase Edge Functions)
**后端模型**: DeepSeek / OpenAI（可配置）

#### 请求格式

```json
{
  "rule_code": "ai_word_lookup",
  "scene": "subtitle",
  "entry": "word",
  "request_id": "uuid-v4",
  "word": "ephemeral",
  "params": {},
  "source_type": "video",
  "source_code": "video_123"
}
```

#### 成功响应格式

```json
{
  "ok": true,
  "rule_code": "ai_word_lookup",
  "cost_cny": 0.01,
  "balance_after": 9.99,
  "result": {
    "word": "ephemeral",
    "translation": "短暂的",
    "phonetic": "/ɪˈfem(ə)rəl/",
    "part_of_speech": "adjective",
    "definition": "lasting for a very short time",
    "examples": [
      "fame in the digital age is often ephemeral"
    ]
  }
}
```

#### 错误响应格式

```json
{
  "ok": false,
  "error": "insufficient_balance",
  "message": "余额不足，请先充值",
  "required_cny": 0.50,
  "balance_cny": 0.00
}
```

#### 计费逻辑

```
请求进入 ai-proxy
     │
     ▼
查询用户余额
     │
     ├── 余额充足？
     │       │
     │      YES → 执行 AI 调用
     │               │
     │               ▼
     │         计算费用（基于 rule_code 费率表）
     │               │
     │               ▼
     │         扣减余额
     │               │
     │               ▼
     │         返回结果 + cost_cny + balance_after
     │
     └── NO → 返回错误 + required_cny + balance_cny
```

**费率表**:

| rule_code | 单价 (¥) | 说明 |
|-----------|----------|------|
| `ai_definition` | 0.005 | 最便宜，简明释义 |
| `ai_word_lookup` | 0.01 | 含音标、例句 |
| `ai_translate` | 0.02 | 句子/段落翻译 |
| `ai_translate_conversation` | 0.02 | 口语化翻译 |
| `ai_tts` | 0.03 | 语音合成 |
| `ai_grammar_check` | 0.04 | 语法检查 |
| `ai_pronunciation_score` | 0.05 | 最贵，语音分析 |

---

## 本地模式（Local AI）

### LocalAiService（统一入口）

**文件位置**: `lib/services/local_ai_service.dart`

```dart
class LocalAiService {
  static LocalAiService get instance => _instance ??= LocalAiService._();

  // 子服务
  final LocalTtsService _tts;      // TTS 合成
  final LocalSttService _stt;      // STT 识别（已移除）
  final LocalModelService _model;   // 模型管理

  // 状态
  bool get isInitialized;
  bool get allModelsReady;
  bool get ttsReady;

  // 初始化
  Future<void> initialize();

  // 功能方法
  Future<String> translate({required String text});  // 翻译
  Future<String?> synthesizeToFile({...});          // TTS
  Future<String> recognizeFromFile({...});          // STT（已废弃）
}
```

### 支持的本地功能

| 功能 | 实现方式 | 系统要求 | 质量 |
|------|----------|----------|------|
| 翻译 (英→中) | iOS MLTranslation | iOS 17.4+ | ⭐⭐⭐⭐ |
| 翻译 (英→中) | ONNX Runtime 模型 | iOS/Android | ⭐⭐⭐ |
| TTS 语音合成 | AVSpeechSynthesizer | iOS 8+ | ⭐⭐⭐⭐ |
| TTS 语音合成 | ONNX TTS 模型 | iOS/Android | ⭐⭐⭐ |
| 单词释义 | iOS TranslationService | iOS 17.4+ | ⭐⭐⭐ |
| STT 语音识别 | ❌ 已移除 | - | - |

### 初始化流程

```dart
// 在 App 启动时初始化（main.dart 或 SplashPage）
void _initLocalAi() async {
  final localAi = LocalAiService.instance;
  
  await localAi.initialize();
  
  if (localAi.allModelsReady) {
    print('✅ 所有本地 AI 模型就绪');
  } else {
    print('⚠️ 部分模型不可用，将降级到云端');
  }
  
  // 监听模型状态变化
  localAi.modelStatusStream.listen((status) {
    print('模型状态变更: $status');
  });
}
```

### IosNativeFeatures（iOS 原生能力）

**文件位置**: `lib/services/ios_native_features.dart`

```dart
class IosNativeFeatures {
  /// iOS 系统翻译（MLTranslation）
  /// - 需要 iOS 17.4+
  /// - 支持多语言对
  /// - 无网络依赖（离线可用）
  static Future<TranslationResult> translate({
    required String text,
    String from = 'en',
    String to = 'zh-Hans',
  }) async {...}
  
  /// 文字转语音（AVSpeechSynthesizer）
  static Future<String> textToSpeech({
    required String text,
    String language = 'en-US',
    double rate = 0.5,
  }) async {...}
  
  /// 语音识别（SF SpeechRecognizer）
  /// 注意：已移除，改用云端方案
}
```

### LocalModelService（模型管理）

**文件位置**: `lib/services/local_model_service.dart`

```dart
class LocalModelService {
  /// 模型状态枚举
  enum LocalModelStatus {
    notAvailable,   // 不可用（未下载/不支持）
    downloading,    // 下载中
    ready,          // 就绪
    error,          // 错误
  }

  /// 模型是否已全部下载
  bool get hasAllModels;

  /// 是否可以使用 AI 功能
  bool get canUseAiFeatures;

  /// 各模型状态流
  Stream<LocalModelStatus> get statusStream;

  /// 下载模型
  Future<void> downloadModel(LocalModelType type);

  /// 删除模型（释放空间）
  Future<void> deleteModel(LocalModelType type);
}
```

---

## 计费与缓存策略

### 缓存机制

**文件位置**: `lib/services/translation_cache_service.dart`（如有）

#### 缓存层级

```
请求 AiService.lookupWord('hello')
     │
     ▼
Level 1: 内存缓存（Map<String, WordDetail>）
     │  命中？→ 直接返回（~0ms）
     │
     ▼ 未命中
Level 2: SQLite 缓存（translation_cache 表）
     │  命中？→ 返回 + 更新内存缓存（~1ms）
     │
     ▼ 未命中
Level 3: 云端 API 调用
     │
     ▼ 返回结果
写入 SQLite 缓存 + 写入内存缓存
```

#### 缓存键规则

```dart
// 缓存 Key 格式
String cacheKey = '${ruleCode}:${word.hashCode}';

// 示例：
// 'ai_word_lookup:12345678'  -> 单词查词
// 'ai_translate:87654321'    -> 句子翻译
```

#### 缓存失效

- **手动清除**: 用户在设置页点击"清除缓存"
- **版本失效**: `_cacheVersion` 递增时旧缓存自动失效
- **时间过期**: 可配置 TTL（默认 7 天）

#### 缓存版本管理

```dart
class AiService {
  /// 当前缓存版本
  static const _cacheVersion = 2;
  
  /// 当 Edge Function prompt 更新时递增此值
  /// 使旧缓存失效，确保用户获取最新质量的翻译
}
```

### 余额管理

#### 查询余额

```dart
// 方式 1：从 AI 响应中获取
final result = await AiService.lookupWord('hello');
print(result.balanceAfter);  // 9.99

// 方式 2：主动查询（通过 SubscriptionProvider）
final balance = ref.watch(subscriptionProvider).balanceCny;
```

#### 余额不足处理

```dart
final result = await AiService.lookupWord('hello');

if (result.isInsufficientBalance) {
  // 显示充值提示
  showDialog(
    context: context,
    builder: (_) => RechargeDialog(
      requiredAmount: result.requiredCny ?? 0,
      currentBalance: result.balanceCny ?? 0,
    ),
  );
}
```

#### 免费额度

| 用户类型 | 每日免费额度 | 说明 |
|----------|--------------|------|
| 未登录 | 10 次 | 仅本地模式 |
| 免费用户 | 50 次 | 用完后提示充值 |
| VIP 用户 | 无限 | 不扣费 |

---

## WordDetail 模型

### 完整定义

**文件位置**: `lib/models/word_detail.dart`

```dart
class WordDetail {
  // === 基本信息 ===
  final String word;                    // 原始单词/文本
  final String? translation;            // 中文翻译
  final String? phonetic;               // 国际音标
  final String? partOfSpeech;           // 词性 (n./v./adj./adv.)
  final String? definition;             // 详细定义
  
  // === 例句与扩展 ===
  final List<String>? examples;          // 例句列表
  final List<String>? synonyms;          // 同义词
  final List<String>? antonyms;          // 反义词
  final String? etymology;               // 词源
  final int? difficultyLevel;            // 难度等级 (1-5)
  
  // === 计费信息 ===
  final double? costCny;                // 本次消耗金额
  final double? balanceAfter;            // 余额
  final bool isFree;                     // 是否免费（VIP/每日免费额度）
  
  // === 错误状态 ===
  final bool isError;                    // 是否为错误对象
  final String? errorMessage;            // 错误描述
  final bool isInsufficientBalance;      // 是否余额不足
  final double? requiredCny;            // 所需金额
  final double? balanceCny;             // 当前余额
  
  // === 构造方法 ===
  factory WordDetail.fromAiResult(Map<String, dynamic> json, ...);
  factory WordDetail.error(String word, String message, {...});
  factory WordDetail.fromLocalResult(...);
}
```

### 使用示例

```dart
void _showWordCard(WordDetail detail) {
  if (detail.isError) {
    // 错误处理
    TDToast.showError(detail.errorMessage!, context: context);
    
    if (detail.isInsufficientBalance) {
      _showRechargeDialog(detail.requiredCny);
    }
    return;
  }
  
  showModalBottomSheet(
    context: context,
    builder: (_) => WordCard(
      word: detail.word,
      phonetic: detail.phonetic ?? '',
      partOfSpeech: detail.partOfSpeech ?? '',
      translation: detail.translation ?? '',
      definition: detail.definition ?? '',
      examples: detail.examples ?? [],
      onPlayPronunciation: () => _playAudio(detail.word),
      onAddToWordbook: () => _addToWordbook(detail),
    ),
  );
}
```

---

## 最佳实践

### ✅ 必须遵守的规范

#### 1. 统一入口调用

```dart
// ✅ 正确：通过 AiService
final result = await AiService.lookupWord(word);

// ❌ 错误：直接调用 Edge Function
final response = await client.functions.invoke('ai-proxy', body: {...});
```

#### 2. 错误处理完整性

```dart
try {
  final result = await AiService.lookupWord(word);
  
  if (result.isError) {
    if (result.isInsufficientBalance) {
      _showRechargePrompt(result.requiredCny);
    } else {
      TDToast.showError(result.errorMessage!, context: context);
    }
    return;
  }
  
  // 正常处理
  _showWordCard(result);
  
} catch (e) {
  TDToast.showError('AI 服务异常', context: context);
  debugPrint('AiService error: $e');
}
```

#### 3. 防抖与节流

```dart
// 对于高频操作（如字幕逐词显示），添加防抖
Timer? _debounceTimer;

void _onWordTap(String word) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 300), () async {
    final detail = await AiService.lookupWord(word);
    _showWordCard(detail);
  });
}
```

#### 4. 批量操作优化

```dart
// ❌ 错误：循环调用（慢且昂贵）
for (final word in words) {
  final result = await AiService.lookupWord(word);
  results.add(result);
}

// ✅ 正确：批量接口（如果支持）或并行调用
final futures = words.map((w) => AiService.lookupWord(w));
final results = await Future.wait(futures);
```

#### 5. 离线降级策略

```dart
Future<WordDetail> _smartLookup(String word) async {
  // 1. 先尝试云端
  try {
    return await AiService.lookupWord(word);
  } catch (e) {
    // 2. 云端失败，尝试本地
    if (LocalAiService.instance.allModelsReady) {
      return await AiService.callAiProxy(
        ruleCode: 'ai_definition',
        word: word,
        preferLocal: true,
      );
    }
    // 3. 都失败
    return WordDetail.error(word, '网络异常且本地模型不可用');
  }
}
```

### ⚠️ 性能优化建议

#### 1. 预加载常用词汇

```dart
// 在视频加载时预取字幕中的生词
Future<void> _preloadWords(List<String> words) async {
  final uniqueWords = words.toSet().take(20);  // 限制数量
  
  for (final word in uniqueWords) {
    // 静默预加载，不展示 UI
    unawaited(AiService.lookupWord(word));
  }
}
```

#### 2. 后台刷新缓存

```dart
// 定期刷新热门词汇的缓存
Timer.periodic(Duration(hours: 1), (timer) async {
  final topWords = await _getRecentLookupWords();
  for (final word in topWords) {
    await AiService.lookupWord(word);  // 刷新缓存
  }
});
```

#### 3. 监控用量

```dart
// 记录 AI 调用日志（用于成本控制）
void _logAiUsage(WordDetail result) {
  if (!result.isError && result.costCny != null) {
    analytics.logEvent(
      name: 'ai_usage',
      parameters: {
        'rule_code': result.ruleCode,
        'cost_cny': result.costCny,
        'word_length': result.word.length,
      },
    );
  }
}
```

---

## 常见问题排查

### Q1: AI 调用一直超时？

**排查步骤**:
1. 检查网络连接
2. 查看 Supabase Edge Function 日志
3. 确认 DeepSeek API Key 有效
4. 检查是否有 Rate Limiting

```dart
try {
  final result = await AiService.lookupWord(word)
      .timeout(Duration(seconds: 10));  // 设置超时
} on TimeoutException {
  TDToast.showWarning('AI 响应较慢，请稍后重试', context: context);
}
```

### Q2: 本地翻译质量差？

**原因**: iOS MLTranslation 对专业术语效果一般。

**解决方案**:
- 重要内容使用云端翻译
- 或启用 ONNX 本地模型（需下载 ~100MB 模型包）

### Q3: 余额扣除但未返回结果？

**原因**: Edge Function 内部异常。

**解决方案**:
- 检查 billing_records 表确认扣费记录
- 联系客服退款
- 在前端实现"补偿机制"：记录未完成的请求，下次启动时重试

### Q4: 如何测试 AI 功能而不产生费用？

**方法 1**: 使用本地模式
```dart
final result = await AiService.callAiProxy(
  ruleCode: 'ai_definition',
  word: 'test',
  preferLocal: true,  // 不走云端
);
```

**方法 2**: Mock 数据（开发环境）
```dart
if (kDebugMode) {
  return WordDetail.fromTestMock(word);  // 返回假数据
}
```

### Q5: 如何扩展新的 AI 功能？

**步骤**:
1. 定义新的 `rule_code`（如 `ai_summarize`）
2. 在 `ai-proxy` Edge Function 中添加处理逻辑
3. 在 AiService 中添加便捷方法
4. 更新费率表
5. 测试并部署

```dart
// AiService 新增方法
static Future<WordDetail> summarizeText(String text) async {
  return callAiProxy(
    ruleCode: 'ai_summarize',
    scene: 'article',
    entry: 'paragraph',
    word: text,
    params: {
      'max_length': 200,
      'style': 'bullet_points',
    },
  );
}
```

---

## 📚 相关文档

- [AiService 实现](../../../lib/services/ai_service.dart)
- [LocalAiService 实现](../../../lib/services/local_ai_service.dart)
- [IosNativeFeatures](../../../lib/services/ios_native_features.dart)
- [WordDetail 模型](../../../lib/models/word_detail.dart)
- [Supabase 集成](./supabase-integration.md) — Edge Functions 调用细节
- [AI 计费体系设计](../../AI 计费体系与 Edge Function 架构设计.md)
- [TDesign 组件库](./tdesign-components.md) — 用于错误提示和充值弹窗 UI

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-07-12 | 初版建立，完整的双模式 AI 架构指南 | AI Assistant |

---

## ✅ 功能清单（待扩展参考）

### 已实现 ✅
- [x] 双模式架构（云端 + 本地）
- [x] 7 种 rule_code 功能
- [x] 自动降级机制
- [x] 多级缓存系统
- [x] 余额管理与不足提示
- [x] iOS MLTranslation 集成
- [x] TTS 本地合成
- [x] 计费与用量追踪

### 待实现 🚧
- [ ] 图片 OCR 识别
- [ ] 文档摘要生成
- [ ] 写作批改（语法+风格）
- [ ] 个性化学习路径推荐
- [ ] 多语言互译（不仅限于英→中）
- [ ] 上下文理解（跨句子的指代消解）
