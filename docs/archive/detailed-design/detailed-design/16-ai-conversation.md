# 16 - AI 英语口语对话功能设计

## 一、功能概述

基于千问 Qwen-Omni-Realtime 全双工实时模型，提供沉浸式英语口语训练体验。
AI 根据当前视频字幕或文章内容主动提问，用户语音回答，AI 给出反馈并继续提问，形成持续对话循环。

### 核心交互流程

```
视频/文章上下文 → Edge Function 构建 instructions
        ↓
WebSocket 全双工连接（Qwen-Omni-Realtime）
        ↓
AI 发起提问（语音 + 文本）
        ↓
用户语音回答（16kHz PCM → 实时 ASR）
        ↓
AI 反馈 + 新问题（24kHz PCM 语音 + 文本）
        ↓
持续循环...
```

## 二、技术选型

### 2.1 核心模型：Qwen-Omni-Realtime

| 特性 | 说明 |
|---|---|
| 协议 | WebSocket (`wss://dashscope.aliyuncs.com/api-ws/v1/realtime`) |
| 推荐模型 | `qwen3.5-omni-plus-realtime`（100轮音频对话，600秒音频时长） |
| 音频输入 | 16kHz 单声道 PCM |
| 音频输出 | 24kHz 单声道 PCM |
| VAD | `semantic_vad`（语义级，过滤语气词和背景噪音） |
| 内置能力 | ASR + LLM + TTS 一体化，无需分段调用 |

### 2.2 为什么不用三段式流水线

| 方案 | Qwen-Omni-Realtime（选用） | Paraformer ASR + Qwen LLM + CosyVoice TTS |
|---|---|---|
| 延迟 | 极低（流式全双工） | 高（3次 API 往返） |
| 打断 | 原生语义打断 | 不支持 |
| 架构复杂度 | 单 WebSocket | 3个服务协调 |
| 成本 | 单一计费 | 三重计费 |

## 三、Edge Function 架构

所有 AI 功能均通过 Supabase Edge Function 统一管理鉴权、计费和上下文注入。

### 3.1 架构总览

```
┌─ Supabase Edge Functions ────────────────────────────────┐
│                                                           │
│  ai-proxy/（已有，扩展路由）                               │
│    ├── ai_definition      单词释义                        │
│    ├── ai_translate       句子翻译 ← 对话翻译也复用此路由  │
│    ├── ai_word_link       词联                            │
│    ├── ai_tts             语音合成                        │
│    └── ai_conversation_settle  对话会话结算（新增）        │
│                                                           │
│  ai-conversation/（新增独立 Edge Function）                │
│    ├── 鉴权 + 计费预检                                    │
│    ├── 查询字幕/文章上下文                                 │
│    ├── 构建个性化 instructions                            │
│    ├── 生成短时 session token (JWT)                       │
│    └── 返回连接参数                                       │
└───────────────────────────────────────────────────────────┘
```

### 3.2 两阶段连接模型

Qwen-Omni-Realtime 使用 WebSocket 长连接传输音频流，而 Supabase Edge Function 是 HTTP 请求-响应模式，
无法直接代理 WebSocket。因此采用两阶段架构：

**阶段一：Edge Function（HTTP）— 会话创建**
- 鉴权（JWT 校验用户身份）
- 计费预检（余额检查）
- 根据 `source_type` + `source_code` 查询字幕或文章内容
- 构建个性化 system instructions
- 生成短时 session token（JWT，有效期 120 分钟，与模型会话上限对齐）
- 返回连接参数 `{ token, instructions, voice, ws_url, conversation_id }`

**阶段二：Flutter 直连 WebSocket — 实时对话**
- 使用阶段一返回的 token + ws_url 建立 WebSocket 连接
- 发送 `session.update` 配置会话（instructions、voice、VAD 参数）
- 音频流双向传输（input_audio_buffer.append / response.audio.delta）
- 对话结束后，Flutter 调用 `ai_conversation_settle` 结算扣费

### 3.3 ai-conversation Edge Function

**请求体：**
```json
{
  "source_type": "subtitle",
  "source_code": "video_code_xxx",
  "voice": "Ethan",
  "scene": "conversation"
}
```

**响应体：**
```json
{
  "ok": true,
  "session_token": "jwt_token_xxx",
  "instructions": "You are an English conversation tutor...",
  "voice": "Ethan",
  "ws_url": "wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=qwen3.5-omni-plus-realtime",
  "cost_cny": 0.01,
  "balance_after": 9.99,
  "conversation_id": "conv_xxx"
}
```

### 3.4 ai_conversation_settle 路由

对话结束后调用，根据实际对话轮次和时长结算费用：

```json
{
  "rule_code": "ai_conversation_settle",
  "conversation_id": "conv_xxx",
  "turn_count": 10,
  "duration_seconds": 180
}
```

## 四、System Instructions 设计

### 4.1 视频/音频场景（基于字幕）

```
You are an English conversation tutor helping a student practice spoken English.
The student is studying the following video/audio content:

Title: {video_title}
Transcript:
{all_subtitle_text_joined}

Conversation Rules:
1. Always speak in English at a natural, moderate pace
2. Start by greeting the student and asking a simple comprehension question about the content
3. After the student responds, give brief encouraging feedback, then ask a follow-up question
4. Gradually increase question difficulty as the conversation progresses
5. Keep each response concise (2-4 sentences)
6. If the student struggles, offer hints or rephrase the question more simply
7. Encourage the student to express personal opinions about the topic
8. If the student asks about a word or phrase, explain it with examples in context
```

### 4.2 文章场景

```
You are an English conversation tutor helping a student practice spoken English.
The student is studying the following article:

Title: {article_title}
Article Content:
{article_sentences_joined}

Conversation Rules:
[same as above]
```

## 五、中文翻译功能（"字幕对话" 开关）

### 5.1 两种翻译策略

| 策略 | 说明 | 适用场景 |
|---|---|---|
| A: Instructions 内置 | 在 system prompt 中要求 AI 附带中文翻译 | 默认策略，零额外成本 |
| B: Edge Function 独立翻译 | AI 回复后调用 `ai_translate` 路由 | 翻译质量要求高时启用 |

**当前采用策略 A**：在 instructions 末尾追加翻译规则：

```
Chinese Translation Rules:
- After each English response, append a Chinese translation on a new line
- Prefix the translation with [中文]
- Keep the translation natural and conversational
- For vocabulary explanations, provide both English definition and Chinese meaning
```

"字幕对话" 开关仅控制 UI 上是否显示 `[中文]` 部分，不产生额外 API 调用。

### 5.2 翻译流程

```
AI 生成回复（英文 + [中文] 翻译）
        ↓
Flutter 解析回复文本，分离英文和中文部分
        ↓
"字幕对话" 开启 → 显示英文 + 中文
"字幕对话" 关闭 → 仅显示英文
```

## 六、Flutter 端架构

### 6.1 新增文件

| 文件路径 | 职责 |
|---|---|
| `lib/services/conversation_service.dart` | 会话管理（创建/结算），调用 Edge Function |
| `lib/services/qwen_realtime_service.dart` | WebSocket 连接管理、音频流收发、事件分发 |
| `lib/providers/conversation_provider.dart` | 对话状态机、消息历史、业务逻辑 |
| `lib/models/conversation_message.dart` | 对话消息数据模型 |
| `lib/views/conversation/conversation_page.dart` | 对话 UI 页面 |
| `lib/widgets/chat_bubble.dart` | 消息气泡组件 |

### 6.2 修改文件

| 文件路径 | 修改内容 |
|---|---|
| `lib/services/ai_service.dart` | 新增 `translateConversationText` 方法 |
| `supabase/functions/ai-proxy/index.ts` | 新增 `ai_conversation_settle` 路由 |
| `supabase/functions/ai-proxy/clients/qwen-chat.ts` | 新增 `translateConversationResponse` |

### 6.3 数据模型

```dart
enum MessageRole { ai, user }

class ConversationMessage {
  final String id;
  final MessageRole role;
  final String text;             // 英文原文
  final String? translation;     // 中文翻译（从 AI 回复中解析）
  final bool isTranscribing;     // 用户语音正在识别中（中间态）
  final DateTime timestamp;
}
```

### 6.4 对话状态机

```dart
enum ConversationState {
  idle,           // 未开始
  connecting,     // 正在创建会话 + 连接 WebSocket
  aiSpeaking,     // AI 正在说话（播放音频中）
  listening,      // 等待/正在听用户说话
  processing,     // AI 正在处理回复
  error,          // 出错
  disconnected,   // 已断开
}
```

状态流转：
```
idle → connecting → aiSpeaking → listening → processing → aiSpeaking → listening → ...
                                                         ↗
                  error ← (任何状态异常)
                  disconnected ← (主动断开或超时)
```

### 6.5 QwenRealtimeService 核心 API

```dart
class QwenRealtimeService {
  WebSocket? _ws;
  StreamController<RealtimeEvent> _eventController;

  /// 建立 WebSocket 连接
  Future<void> connect({
    required String wsUrl,
    required String sessionToken,
  });

  /// 配置会话（session.update）
  void updateSession({
    required String instructions,
    String voice = 'Ethan',
    String inputAudioFormat = 'pcm',
    String outputAudioFormat = 'pcm',
  });

  /// 发送音频数据（16kHz PCM，Base64 编码）
  void sendAudio(Uint8List pcmData);

  /// 事件流（供 Provider 监听）
  Stream<RealtimeEvent> get events;

  /// 断开连接
  void disconnect();
}
```

### 6.6 需要处理的 WebSocket 事件

**客户端发送：**

| 事件 | 说明 |
|---|---|
| `session.update` | 配置会话参数 |
| `input_audio_buffer.append` | 发送录音 PCM 数据（Base64） |

**服务端接收：**

| 事件 | 说明 | 处理 |
|---|---|---|
| `conversation.item.input_audio_transcription.delta` | 用户语音识别中间结果 | UI 实时显示识别文字 |
| `conversation.item.input_audio_transcription.completed` | 用户语音识别完成 | 添加到消息列表 |
| `response.audio_transcript.delta` | AI 回复文本流 | UI 实时追加显示 |
| `response.audio_transcript.done` | AI 回复文本完成 | 完成 AI 消息，解析翻译 |
| `response.audio.delta` | AI 回复音频流（Base64 PCM） | 实时播放 24kHz |
| `response.audio.done` | AI 音频完成 | 标记播放结束 |
| `response.done` | AI 回复结束 | 状态切回 listening |

### 6.7 音频录制与播放

- **录制**：使用项目已有的 `record: ^6.0.0`，配置 16kHz、单声道、PCM 格式，流式输出
- **播放**：使用 `audioplayers: ^6.1.0` 或原生平台通道，播放 24kHz PCM 流
- 音频分包策略：每 100ms 发送一次 `input_audio_buffer.append`（约 3200 bytes @ 16kHz 16bit）

## 七、UI 设计

### 7.1 页面布局

```
┌────────────────────────────────┐
│ ←  AI English Conversation    │
│              [字幕对话 ●]      │  ← 开关按钮
├────────────────────────────────┤
│ Source: [视频/文章标题]         │  ← 上下文来源标签
│ ● Connected  02:34            │  ← 连接状态 + 时长
├────────────────────────────────┤
│                                │
│  🤖 What did you learn from   │  ← AI 消息（左对齐）
│     the video about...?       │
│     [中文] 你从视频中了解到了    │  ← 翻译（灰色，字幕对话开启时显示）
│     什么？                     │
│                    10:23 AM   │
│                                │
│     I learned that...  🎤     │  ← 用户消息（右对齐）
│                    10:23 AM   │
│                                │
│  🤖 Great! Can you tell me    │
│     more about...             │
│     [中文] 很好！你能详细说说吗？│
│                    10:24 AM   │
│                                │
├────────────────────────────────┤
│   🎤 松开发送                   │  ← 按住说话
│       ○ (大蓝色录音按钮)        │
└────────────────────────────────┘
```

### 7.2 入口

- 视频播放页：添加 "AI 对话" 按钮，自动传入当前视频的字幕
- 文章阅读页：添加 "AI 对话" 按钮，自动传入当前文章内容
- 支持传递 `source_type` + `source_code` 参数

### 7.3 "字幕对话" 开关

- 右上角圆角按钮，蓝底白字=开启，灰底=关闭
- 开启时：AI 消息气泡显示英文 + 中文翻译
- 关闭时：仅显示英文原文
- 状态保存在 Provider 中，不影响 AI 生成逻辑

## 八、计费模型

### 8.1 计费项

| 计费项 | rule_code | 计费方式 | 说明 |
|---|---|---|---|
| 对话会话创建 | `ai_conversation` | 按次/按时长 | 创建会话时预扣基础费用 |
| 对话会话结算 | `ai_conversation_settle` | 按实际用量 | 根据轮次和时长补扣或退还 |
| 对话中翻译 | `ai_translate` | 按次 | 仅策略 B 时使用 |

### 8.2 会话生命周期

```
创建会话（预扣费）→ 对话进行中 → 结束对话（结算）
                                    ↓
                          实际费用 = 基础费 + 轮次费 × 实际轮次
                          差额补扣或退还
```

## 九、使用限制

| 限制 | 值 |
|---|---|
| 单次会话最长 | 120 分钟（模型限制） |
| 最大音频轮次 | 100 轮（qwen3.5-omni-plus-realtime） |
| 最大音频时长 | 600 秒 |
| 音频输入格式 | 16kHz 单声道 PCM |
| 音频输出格式 | 24kHz 单声道 PCM |
| 支持语言 | 113 种语音识别 + 36 种语音生成 |
| 可用音色 | 55 种（47 多语言 + 8 方言） |

## 十、关键风险与应对

| 风险 | 应对方案 |
|---|---|
| Flutter WebSocket 音频延迟 | PCM 分包 100ms/包，使用 `web_socket_channel` |
| 24kHz PCM 实时播放 | 使用 `audioplayers` 或原生平台通道播放原始 PCM |
| 上下文过长（字幕很多） | 截取摘要或最近 N 条字幕传入 instructions |
| 会话超时 120 分钟 | UI 显示倒计时，到时间提示重新连接 |
| 网络断开 | 自动重连机制，保留对话历史 |
| session token 泄露 | JWT 短时有效（120 分钟），仅含必要声明 |
