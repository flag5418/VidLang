# AI 服务集成知识库

> **版本**: V1.1 | **日期**: 2026-07-13
> **状态**: ✅ 已启用 - 多通道混合 AI 架构（Edge Function + 直连 WebSocket/HTTP + 本地模型）
> **核心文件**: `lib/services/ai_service.dart` 及多个专用服务

---

## 📋 目录

1. [架构概览](#一架构概览)
2. [通道分类与选路规则](#二通道分类与选路规则)
3. [通道一：AiService → ai-proxy Edge Function](#三通道一aiservice--ai-proxy-edge-function)
4. [通道二：TTS 直连 DashScope](#四通道二tts-直连-dashscope)
5. [通道三：STT/评测 声通 WebSocket](#五通道三stt评测-声通-websocket)
6. [通道四：AI 对话 Qwen Realtime WebSocket](#六通道四ai-对话-qwen-realtime-websocket)
7. [通道五：本地模型 LocalAiService](#七通道五本地模型-localaiservice)
8. [WordDetail 模型](#八worddetail-模型)
9. [缓存策略](#九缓存策略)
10. [计费机制](#十计费机制)
11. [最佳实践](#十一最佳实践)

---

## 一、架构概览

### 1.1 核心原则

**VidLang 的 AI 服务采用「多通道混合架构」——不同功能走不同的调用路径，不再有唯一的统一入口。**

| 原则 | 说明 |
|------|------|
| **按功能选路** | 不同 AI 功能使用最合适的技术路径（Edge Function / WebSocket 直连 / HTTP 直连） |
| **计费统一入口** | 所有产生费用的操作，最终都通过 `ai-proxy` Edge Function 或独立 Edge Function 完成扣费 |
| **本地降级可选** | 部分功能支持 `preferLocal: true` 降级到 iOS 系统翻译或 ONNX 模型 |

### 1.2 整体架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        VidLang App (Flutter)                        │
│                                                                     │
│  ┌──────────┐ ┌──────────────┐ ┌─────────────┐ ┌────────────────┐ │
│  │ AiService │ │ TtsService   │ │ShengtongEval│ │QwenRealtimeSvc │ │
│  │ (查词/翻译│ │→UnifiedTts   │ │(发音评测)    │ │(AI 对话)       │ │
│  │ /释义)    │ │→DashScopeTTS │ │              │ │                │ │
│  └─────┬────┘ └──────┬───────┘ └──────┬──────┘ └───────┬────────┘ │
│        │              │                │                │          │
│        ▼              ▼                ▼                ▼          │
│  ┌──────────┐ ┌──────────────┐ ┌─────────────┐ ┌────────────────┐ │
│  │ ai-proxy  │ │ DashScope    │ │ 声通 API     │ │ Qwen-Omni      │ │
│  │ Edge Func │ │ HTTP/SSE TTS │ │ WebSocket    │ │ Realtime WS    │ │
│  │ (Supabase)│ │ (阿里云)     │ │ (stkouyu.com)│ │ (DashScope)    │ │
│  └─────┬────┘ └──────────────┘ └─────────────┘ └────────────────┘ │
│        │                                                         │
│        ▼                                                         │
│  ┌──────────┐  ┌──────────────┐                                   │
│  │ DeepSeek/│  │ LocalAiService│ (iOS MLTranslation / AVSpeech)   │
│  │ Qwen API │  │ (离线降级)    │                                   │
│  └──────────┘  └──────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 五大通道总览

| # | 通道名称 | 入口服务 | 协议 | 用途 | 计费方式 |
|---|---------|----------|------|------|---------|
| 1 | **Edge Function 代理** | `AiService` | HTTPS → Supabase → Qwen/DeepSeek | 查词、翻译、释义、词联、对话结算、评测分析、出题、学习建议 | ai-proxy 内部扣费 |
| 2 | **TTS 直连** | `UnifiedTtsService` → `DashScopeTtsService` | HTTP SSE (DashScope) | 所有语音合成（播放器朗读、清晰朗读、单词发音） | 不经 Edge Function，免费/按量 |
| 3 | **STT/评测直连** | `ShengtongEvaluator` | WebSocket (声通) | 发音评分、跟读评测 | evaluation-storage Edge Function 记录结果 |
| 4 | **AI 对话直连** | `QwenRealtimeService` | WebSocket (DashScope Realtime) | 口语练习实时对话 | ai-conversation 创建会话 + question/answer 结算 |
| 5 | **本地模型** | `LocalAiService` | iOS MLTranslation / ONNX / AVSpeech | 翻译降级、TTS 降级 | 免费 |

---

## 二、通道分类与选路规则

### 2.1 功能 → 通道映射表

| 功能 | 主通道 | 备用通道 | 代码入口 |
|------|--------|----------|----------|
| **单词查词/释义** | ① AiService (`ai_definition`) | ⑤ LocalAiService (iOS 翻译) | `AiService.getDefinition()` |
| **句子/段落翻译** | ① AiService (`ai_translate`) | ⑤ LocalAiService | `AiService.translateText()` |
| **对话消息翻译** | ① AiService (`ai_translate_conversation`) | ⑤ LocalAiService | `AiService.translateConversationText()` |
| **词联网络** | ① AiService (`ai_word_link`) | 无 | `AiService.callAiProxy(ruleCode:'ai_word_link')` |
| **TTS 语音合成** | ② DashScope 直连 | ⑤ LocalTtsService (AVSpeech) | `UnifiedTtsService.synthesize()` |
| **TTS（备用路径）** | ① AiService (`ai_tts`) — ⚠️ 死代码，无调用者 | — | `AiService.getTtsAudio()` |
| **发音评分（声通）** | ③ ShengtongEvaluator WebSocket | — | `ShengtongEvaluator.evaluate()` |
| **AI 评测分析** | ① AiService (`ai_audio_evaluation`) | — | `AiEvaluationService.analyzePronunciation()` |
| **AI 对话（实时）** | ④ QwenRealtimeService WebSocket | — | `QwenRealtimeService.connect()` |
| **对话会话创建** | ① `ai-conversation` Edge Function | — | `ConversationService.createSession()` |
| **对话问答计费** | ① AiService (`ai_conversation_question/answer/settle`) | — | `ConversationService` 内部 |
| **AI 出题** | ① AiService (`ai_test_plan`) | — | 测试引擎内部 |
| **学习建议** | ① AiService (`ai_learning_suggestion`) | — | 学习模块内部 |

### 2.2 调用决策流程

```
开发者需要 AI 功能
       │
       ▼
  是哪种功能？
       │
       ├── 查词/翻译/释义/词联？
       │       │
       │       ▼
       │  AiService.getDefinition() / translateText() / callAiProxy()
       │       │
       │       ├── preferLocal=true? → LocalAiService (iOS MLTranslation)
       │       └── preferLocal=false(默认) → ai-proxy Edge Function → Qwen
       │
       ├── TTS 语音合成？
       │       │
       │       ▼
       │  UnifiedTtsService.synthesize()
       │       │
       │       ├── 免费模式? → LocalTtsService (AVSpeechSynthesizer)
       │       └── 收费模式? → DashScopeTtsService (HTTP SSE 直连)
       │
       ├── 发音评测？
       │       │
       │       ▼
       │  ShengtongEvaluator (WebSocket 直连声通)
       │       + AiEvaluationService (ai_audio_evaluation, 可选 AI 分析)
       │
       ├── AI 对话？
       │       │
       │       ▼
       │  QwenRealtimeService (WebSocket 直连 DashScope Realtime)
       │       + ConversationService (会话创建/结算走 Edge Function)
       │
       └── 其他 AI 功能？
               │
               ▼
          AiService.callAiProxy(ruleCode: 'xxx')
```

---

## 三、通道一：AiService → ai-proxy Edge Function

### 3.1 核心文件

| 文件 | 说明 |
|------|------|
| `lib/services/ai_service.dart` | 统一 Edge Function 调用入口 |
| `supabase/functions/ai-proxy/index.ts` | Edge Function 主路由（Deno 运行时） |

### 3.2 AiService 公共方法列表

```dart
class AiService {
  // ═══ 核心调用入口 ═══
  static Future<WordDetail> callAiProxy({...});         // 通用调用，返回 WordDetail
  static Future<Map<String, dynamic>> callAiProxyRaw({...}); // 通用调用，返回原始 JSON

  // ═══ 业务便捷方法 ═══
  static Future<WordDetail> getDefinition({...});       // 单词释义（ai_definition）
  static Future<WordDetail> translateText({...});        // 文本翻译（ai_translate）
  static Future<String?> translateConversationText({...}); // 对话翻译（ai_translate_conversation）
  static Future<Map<String, dynamic>?> getTtsAudio({...}); // TTS（ai_tts）⚠️ 无调用者

  // ═══ 辅助方法 ═══
  static String _resolveScene(String? sourceType);       // sourceType → scene 映射
}
```

### 3.3 callAiProxy 参数详解

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `ruleCode` | String | ✅ | 功能规则码（见 §3.5 路由表） |
| `scene` | String | ✅ | 使用场景（player/reader/wordbook/conversation/shadow_reader 等） |
| `entry` | String | ✅ | 操作类型（word/trans_btn/tts_btn/translate_reply/ai_analysis 等） |
| `word` | String | ✅ | 待处理文本（部分 ruleCode 通过 params 传 text） |
| `sourceType` | String | ❌ | 来源类型（video/article/music/wordbook），用于动态设置 scene |
| `sourceCode` | String | ❌ | 来源标识（资源 ID），用于计费溯源 |
| `params` | Map | ❌ | 业务参数（因 ruleCode 而异） |
| `billing` | Map | ❌ | 显式指定计费元数据（action_key, resource_type 等） |
| `preferLocal` | bool | ❌ | 是否优先本地模型（默认 false） |

### 3.4 scene 动态映射

`sourceType` 到 `scene` 的自动映射（`_resolveScene()` 方法）：

| sourceType | scene | 使用场景 |
|------------|-------|----------|
| `article` | `reader` | 文章阅读器 |
| `video` | `player` | 视频播放器 |
| `music` | `player` | 音频播放器（复用 player） |
| `wordbook` | `wordbook` | 生词本 |
| 其他/null | `player` | 默认 |

### 3.5 ai-proxy 支持的完整路由表（ROUTES）

以下是在 `supabase/functions/ai-proxy/index.ts` 中实际注册的所有路由：

#### Chat 类路由（调用 Qwen/DeepSeek LLM）

| rule_code | 功能 | 主要参数 | Flutter 调用方式 |
|-----------|------|----------|-----------------|
| `ai_definition` | 单词释义 | `word`, `sentence` | `AiService.getDefinition()` |
| `ai_translate` | 通用翻译 | `text`, `target_language` | `AiService.translateText()` |
| `ai_translate_conversation` | 对话消息翻译 | `text` | `AiService.translateConversationText()` |
| `ai_word_link` | 词联网络 | `word`, `sentence` | `AiService.callAiProxy(ruleCode:'ai_word_link')` |
| `ai_chat` | 通用 AI 对话 | `prompt`/`text`, `system_prompt`, `temperature`, `max_tokens` | `AiService.callAiProxy(ruleCode:'ai_chat')` |
| `ai_translate_article` | 文章翻译 | `prompt` | `AiService.callAiProxy(ruleCode:'ai_translate_article')` |
| `ai_audio_evaluation` | AI 发音分析 | 评测结果全量字段（overall_score, fluency_score, error_words...） | `AiEvaluationService.analyzePronunciation()` via `callAiProxyRaw()` |
| `ai_test_plan` | AI 出题 | （测试引擎传入） | 测试引擎内部 |
| `ai_learning_suggestion` | AI 学习建议 | （学习模块传入） | 学习模块内部 |

#### 对话类路由（纯计费/结算，不调外部 AI）

| rule_code | 功能 | 说明 |
|-----------|------|------|
| `ai_conversation_settle` | 对话会话结算 | 写入 conversation_session 的 summary/cost |
| `ai_conversation_question` | AI 提问计费 | 记录一轮对话的提问费用 |
| `ai_conversation_answer` | AI 回复计费 | 记录一轮对话的回复费用 |

#### TTS 路由（独立处理）

| rule_code | 功能 | 说明 |
|-----------|------|------|
| `ai_tts` | 文本转语音 | 调用 qwenTts/qwenTtsStreaming，⚠️ 当前无 Flutter 调用者（死代码） |

### 3.6 请求/响应格式

**请求**:
```json
{
  "rule_code": "ai_definition",
  "scene": "player",
  "entry": "word",
  "request_id": "uuid-v4",
  "word": "ephemeral",
  "params": {},
  "source_type": "video",
  "source_code": "video_123"
}
```

**成功响应**:
```json
{
  "ok": true,
  "rule_code": "ai_definition",
  "cost_cny": 0.005,
  "balance_after": 9.995,
  "result": { /* 结构化数据，因 rule_code 而异 */ }
}
```

**错误响应**:
```json
{
  "ok": false,
  "error": "insufficient_balance",     // insufficient_balance / unauthorized / unknown_rule_code / ...
  "message": "余额不足，请先充值",
  "required_cny": 0.50,
  "balance_cny": 0.00
}
```

---

## 四、通道二：TTS 直连 DashScope

### 4.1 核心文件

| 文件 | 说明 |
|------|------|
| `lib/services/unified_tts_service.dart` | TTS 统一入口（分流+缓存） |
| `lib/services/tts_service.dart` | TTS 业务封装（播放器集成） |
| `lib/services/dashscope_tts_service.dart` | DashScope HTTP SSE TTS 实现 |
| `lib/services/local_tts_service.dart` | 本地 TTS（AVSpeechSynthesizer，免费模式兜底） |

### 4.2 分流逻辑

```
UnifiedTtsService.synthesize(text)
       │
       ├── 免费模式？
       │       │
       │      YES → LocalTtsService (AVSpeechSynthesizer)
       │               │
       │              iOS: AVSpeechSynthesizer
       │              Android: TextToSpeech
       │
       └── 收费模式？（默认）
               │
               ├── ① 检查磁盘缓存（SHA256 hash key, LRU, Documents/tts_cache/）
               │       │
               │      HIT → 直接返回缓存音频路径
               │
               └── ② 缓存未命中 → DashScopeTtsService.synthesize()
                       │
                       HTTP SSE 流式连接 DashScope (qwen3-tts-flash)
                       → 下载完整 MP3 → 写入缓存 → 返回路径
```

### 4.3 缓存机制

| 属性 | 值 |
|------|-----|
| 存储位置 | `Documents/tts_cache/` |
| 缓存 Key | 文本内容的 SHA256 hash（`.mp3` 后缀） |
| 淘汰策略 | LRU，最大条数可配置（`SettingsService.ttsCacheSize`，默认 20） |
| 格式 | MP3 |

### 4.4 与 ai_tts 的关系

`AiService.getTtsAudio()` 方法仍然存在于代码中，它通过 `ai-proxy` Edge Function 的 `ai_tts` 路由调用千问 TTS。**但此方法当前没有任何调用者**，属于保留的死代码。所有实际的 TTS 调用均走 `UnifiedTtsService → DashScopeTtsService` 直连路径。

---

## 五、通道三：STT/评测 声通 WebSocket

### 5.1 核心文件

| 文件 | 说明 |
|------|------|
| `lib/services/shengtong_evaluator.dart` | 声通 WebSocket 评测客户端 |
| `lib/services/ai_evaluation_service.dart` | 基于声通结果的 AI 分析（走 ai-proxy） |
| `lib/services/evaluation_storage_service.dart` | 评测结果存储（走 evaluation-storage Edge Function） |
| `lib/models/shengtong_evaluation_result.dart` | 评测结果数据模型 |

### 5.2 调用链路

```
用户录音完成
       │
       ▼
ShengtongEvaluator.evaluate(audioPath, refText)
       │
       ├── WebSocket 连接 stkouyu.com
       ├── 上传 PCM 音频 + 参考文本
       ├── 接收结构化评测结果（ShengtongEvaluationResult）
       │
       ├── [可选] AiEvaluationService.analyzePronunciation()
       │       │
       │       ▼
       │   AiService.callAiProxyRaw(ruleCode:'ai_audio_evaluation')
       │   → 将声通结果发给 Qwen → 获取个性化改进建议
       │
       └── [必须] EvaluationStorageService.save()
               │
               ▼
           evaluation-storage Edge Function → 写入云端
```

### 5.3 密钥来源

声通的 AppKey/APIKey/SecretKey 从 Supabase `app_settings` 表动态加载（`AppKeysService`），非硬编码。

---

## 六、通道四：AI 对话 Qwen Realtime WebSocket

### 6.1 核心文件

| 文件 | 说明 |
|------|------|
| `lib/services/qwen_realtime_service.dart` | Qwen-Omni-Realtime WebSocket 客户端 |
| `lib/services/conversation_service.dart` | 对话会话管理（创建/历史/结算） |
| `lib/models/conversation_message.dart` | 对话消息模型 |

### 6.2 调用链路

```
用户进入 AI 对话模式
       │
       ├── 1. ConversationService.createSession()
       │       │
       │       ▼
       │   ai-conversation Edge Function → 创建 conversation_session 记录
       │   返回 session_id + instructions（基于视频/文章上下文构建）
       │
       ├── 2. QwenRealtimeService.connect(wsUrl, apiKey)
       │       │
       │       ▼
       │   WebSocket 直连 DashScope Qwen-Omni-Realtime
       │   全双工通信：音频收发 + 文本消息
       │
       └── 3. 对话中每轮（question / answer）
               │
               ▼
           AiService.callAiProxy(ruleCode:'ai_conversation_question' or '_answer')
           → ai-proxy Edge Function 扣费记录
           
       └── 4. 对话结束
               │
               ▼
           AiService.callAiProxy(ruleCode:'ai_conversation_settle')
           → 写入 summary / total_cost / message_count
```

### 6.3 认证方式

DashScope WebSocket 使用 Bearer Token 认证：
```dart
headers: {
  'Authorization': 'Bearer $apiKey',  // qwenApiKey from AppKeysService
}
```

---

## 七、通道五：本地模型 LocalAiService

### 7.1 核心文件

| 文件 | 说明 |
|------|------|
| `lib/services/local_ai_service.dart` | 本地 AI 统一入口 |
| `lib/services/local_model_service.dart` | 模型下载/状态管理 |
| `lib/services/local_tts_service.dart` | 本地 TTS（Piper / AVSpeech） |
| `lib/services/local_stt_service.dart` | 本地 STT（已废弃保留） |
| `lib/services/ios_native_features.dart` | iOS 原生能力（MLTranslation / AVSpeech） |

### 7.2 支持的功能

| 功能 | 实现方式 | 系统要求 | 质量 | 状态 |
|------|----------|----------|------|------|
| 翻译 (英→中) | iOS MLTranslation | iOS 17.4+ | ⭐⭐⭐⭐ | ✅ 可用 |
| 翻译 (英→中) | ONNX Runtime 模型 | iOS/Android | ⭐⭐⭐ | ✅ 可用 |
| TTS 语音合成 | AVSpeechSynthesizer | iOS 8+ | ⭐⭐⭐⭐ | ✅ 免费模式使用 |
| TTS 语音合成 | Piper TTS (ONNX) | iOS/Android | ⭐⭐⭐ | ✅ 可选 |
| 单词释义 | iOS TranslationService | iOS 17.4+ | ⭐⭐⭐ | ✅ 降级使用 |
| STT 语音识别 | — | — | — | ❌ 已移除 |

### 7.3 触发条件

本地模型仅在调用方显式指定 `preferLocal: true` 时启用：

```dart
// 示例：强制使用本地翻译
final result = await AiService.translateText(
  text: 'Hello world',
  preferLocal: true,  // ← 关键参数
);
```

不支持全局切换模式（文档旧版描述的 `aiModeProvider` 已不存在）。

---

## 八、WordDetail 模型

### 8.1 核心文件

`lib/models/word_detail.dart`

### 8.2 实际字段定义

```dart
class WordDetail {
  // === 基本信息 ===
  final String word;                          // 原始单词/文本
  final PronounceInfo pronounce;              // 音标+音频（uk/us 分离）
  final List<WordDefinition> definitions;     // 释义列表（多词性、多释义）
  final List<WordExample> standaloneExamples;  // 独立例句
  final DifficultyLevel difficulty;            // 难度等级
  final WordMorphology? morphology;           // 词形变化（复数/过去式等）
  final String? mnemonic;                     // 助记法

  // === 上下文增强（句子中查词时填充）===
  final String? contextSentence;              // 所在句子
  final String? sentenceTranslation;          // 句子翻译
  final String? wordMeaningInContext;         // 句中词义

  // === 简单翻译模式 ===
  final String? translation;                  // 中文翻译（sentence mode）

  // === 状态与来源 ===
  final bool success;
  final String? error;
  final double? costCny;                      // 本次消耗
  final double? balanceAfter;                 // 余额
  final String source;                        // 数据来源标识
  final bool isSentenceMode;                  // 是否为短句翻译模式
  final bool languagePackRequired;            // 是否需要下载语言包
}
```

### 8.3 子结构

```dart
/// 音标信息（分离英式/美式）
class PronounceInfo {
  final String? ukPhonetic;     // 英式音标 /.../
  final String? usPhonetic;     // 美式音标 /.../
  final String? ukAudioUrl;     // 英式发音 URL
  final String? usAudioUrl;     // 美式发音 URL
}

/// 单条释义
class WordDefinition {
  final String? partOfSpeech;           // 词性
  final String? chineseMeaning;         // 中文释义
  final String? englishMeaning;         // 英文释义
  final List<WordExample> examples;     // 配套例句
}

/// 例句
class WordExample {
  final String english;
  final String chinese;
  final String? audioUrl;
}

/// 词形变化
class WordMorphology {
  final String? plural;           // 复数
  final String? pastTense;        // 过去式
  final String? pastParticiple;   // 过去分词
  final String? presentParticiple; // 现在分词
  final String? thirdPerson;      // 第三人称单数
  final String? comparative;      // 比较级
  final String? superlative;      // 最高级
  final List<String> synonyms;    // 同义词
  final List<String> antonyms;    // 反义词
}
```

### 8.4 工厂方法

| 方法 | 用途 | source 标记 |
|------|------|-------------|
| `WordDetail.fromAiResult(result)` | 从 ai-proxy Edge Function 响应构造 | `'ai_enriched'` |
| `WordDetail.fromJson(json)` | 从 JSON（含缓存）构造 | 按 json 中的 source |
| `WordDetail.fromNativeDict(entry)` | 从本地词典数据构造 | `'native'` |
| `WordDetail.error(word, msg)` | 构造错误对象 | `'ai'`（余额不足时） |

### 8.5 source 来源值一览

| source 值 | 含义 |
|-----------|------|
| `'native'` | 本地词典 |
| `'ai_enriched'` | AI Edge Function 返回（含上下文增强） |
| `'local_ai'` | 本地模型（MLTranslation/ONNX） |
| `'ios_translate'` | iOS 系统翻译 |
| `'ai'` | AI 错误（含余额不足） |

---

## 九、缓存策略

### 9.1 单词缓存（word_cache 表）

**适用范围**: `AiService.getDefinition()` 的查词结果

| 属性 | 值 |
|------|-----|
| 存储位置 | Supabase 云端 `word_cache` 表（非本地 SQLite） |
| 缓存 Key | 单词小写（`word.toLowerCase().trim()`） |
| 版本控制 | `_cacheVersion = 2`，prompt 更新时递增使旧缓存失效 |
| 冲突策略 | UPSERT（`ON CONFLICT(word)`） |
| 热度追踪 | `query_count` 字段（通过 RPC `bump_word_cache_count` 递增） |

**三级缓存策略**:

```
getDefinition('hello', contextSentence: '...')
       │
       ├── ① 无上下文？检查 word_cache 表
       │       │
       │      HIT → 直接返回 WordDetail
       │
       ├── ② 有上下文？检查是否已有该句的 contextSentenceInfo
       │       │
       │      完全命中 → 返回
       │      部分命中 → 仅补充 contextSentenceInfo（enrichWithContext）
       │
       ├── ③ preferLocal=true？尝试 iOS MLTranslation
       │
       └── ④ 全部未命中 → 调用 ai-proxy (ai_definition)
               │
               ▼
           写入 word_cache 表（含 cache_version）
```

### 9.2 TTS 缓存（磁盘文件）

详见 §4.3。

### 9.3 注意事项

- **不存在** `translation_cache_service.dart` 或内存级翻译缓存
- **不存在** 全局 TTL 过期机制（依赖 `_cacheVersion` 版本失效）
- 缓存清理通过用户手动"清除缓存"触发

---

## 十、计费机制

### 10.1 计费入口汇总

| 产生费用的操作 | 计费方式 | 扣费位置 |
|---------------|---------|---------|
| 查词/释义 (`ai_definition`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| 翻译 (`ai_translate`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| 词联 (`ai_word_link`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| 对话提问 (`ai_conversation_question`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| 对话回复 (`ai_conversation_answer`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| 对话结算 (`ai_conversation_settle`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| AI 评测分析 (`ai_audio_evaluation`) | pricing_rule 表费率 | ai-proxy 内部 deduct() |
| TTS（DashScope 直连） | **不计费**（或按 DashScope API 用量） | 不经过 ai-proxy |
| 声通评测（WebSocket 直连） | **不计费**（或按声通套餐） | 不经过 ai-proxy |
| AI 对话实时（WebSocket 直连） | **通过 question/answer 分轮计费** | ai-proxy |

### 10.2 费率配置

费率存储在 Supabase `pricing_rule` 表中，可在后台随时调整。非硬编码。

### 10.3 余额管理

```dart
// 从 AI 响应获取余额
final result = await AiService.getDefinition(word: 'hello');
print(result.balanceAfter);  // 9.995

// 余额不足判断
if (result.isInsufficientBalance) {
  // 显示充值提示
  // result.requiredCny → 所需金额
  // result.balanceCny → 当前余额
}
```

---

## 十一、最佳实践

### ✅ 必须遵守的规范

#### 1. 按功能选择正确的通道

```dart
// ✅ 单词查词 → AiService
final detail = await AiService.getDefinition(word: 'hello');

// ✅ TTS 合成 → UnifiedTtsService（不要用 AiService.getTtsAudio）
final ttsResult = await UnifiedTtsService.instance.synthesize(text: 'Hello');

// ✅ 发音评测 → ShengtongEvaluator
final evalResult = await ShengtongEvaluator.evaluate(...);

// ✅ AI 对话 → QwenRealtimeService
await QwenRealtimeService.instance.connect(wsUrl: url, apiKey: key);
```

#### 2. 传递 sourceType/sourceCode

```dart
// ✅ 正确：传递资源溯源信息
final detail = await AiService.getDefinition(
  word: 'ephemeral',
  sourceType: 'video',      // 标识来自视频
  sourceCode: 'video_123',  // 具体 video ID
);

// ❌ 错略：不传溯源信息（无法归集消费统计）
final detail = await AiService.getDefinition(word: 'ephemeral');
```

#### 3. 错误处理完整性

```dart
try {
  final detail = await AiService.getDefinition(word: word);
  
  if (!detail.success) {
    if (detail.isInsufficientBalance) {
      _showRechargePrompt(detail);
    } else {
      TDToast.showError(detail.error ?? 'AI 服务异常');
    }
    return;
  }
  
  _showWordCard(detail);
} catch (e) {
  TDToast.showError('AI 服务异常');
}
```

#### 4. 防抖（高频查词场景）

```dart
Timer? _debounceTimer;

void _onWordTap(String word) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
    final detail = await AiService.getDefinition(word: word);
    _showWordCard(detail);
  });
}
```

### ⚠️ 常见误区

| 误区 | 正确做法 |
|------|---------|
| 认为 AiService 是唯一 AI 入口 | TTS/STT/对话各有独立通道 |
| 使用 `lookupWord()` 方法 | 该方法不存在，应使用 `getDefinition()` |
| `ai_tts` 用于生产 TTS | 它是死代码，TTS 应走 `UnifiedTtsService` |
| `ai_pronunciation_score` 用于评分 | 评测走 `ShengtongEvaluator` 直连；AI 分析走 `ai_audio_evaluation` |
| 翻译缓存走本地 SQLite | 实际走 Supabase `word_cache` 云端表 |

---

## 📚 相关文档

- [Supabase 集成指南](./supabase-integration.md) — Edge Functions 清单与多通道架构总览
- [计费体系设计](../modules/billing-redesign.md) — pricing_rule / billing-center / 充值策略
- [服务层架构](./services-architecture.md) — 各服务的详细说明
- [数据库设计](./database-design.md) — word_cache / pricing_rule / billing_records 表结构
- [架构总览](../architecture/overview-V1.1.md) — 产品架构与技术栈

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| V1.0 | 2026-07-12 | 初版建立（双模式 AI 架构指南） |
| V1.1 | 2026-07-13 | **全面重写**：核心假设从「统一入口」修正为「多通道混合架构」；新增 5 大通道分类（Edge Function/TTS直连/STT直连/对话WebSocket/本地模型）；删除不存在的 `lookupWord()`/`ai_word_lookup`/`ai_pronunciation_score`/`ai_grammar_check`；更新 WordDetail 模型为实际字段（pronounce/definitions/morphology/contextSentence 等）；修正缓存描述为 word_cache 云端表（非本地SQLite）；标注 `ai_tts` 为死代码；更新 ai-proxy 完整路由表（12 个 rule_code）；补充 TTS/STT/对话的完整调用链路 |

---

**最后更新**: 2026-07-13
**维护者**: VidLang 开发团队
