import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 消息角色
enum MessageRole { ai, user }

/// AI 对话消息
class ConversationMessage {
  final String id;
  final MessageRole role;

  /// 英文原文
  final String text;

  /// 中文翻译（从 AI 回复中解析 [中文] 部分，或独立翻译获取）
  final String? translation;

  /// 用户语音正在识别中（中间态，显示识别中的文字）
  final bool isTranscribing;

  /// AI 正在生成中（流式输出未完成）
  final bool isStreaming;

  final DateTime timestamp;

  ConversationMessage({
    String? id,
    required this.role,
    required this.text,
    this.translation,
    this.isTranscribing = false,
    this.isStreaming = false,
    DateTime? timestamp,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  /// 创建 AI 消息（流式中间态）
  ConversationMessage copyWith({
    String? text,
    String? translation,
    bool? isTranscribing,
    bool? isStreaming,
  }) {
    return ConversationMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      translation: translation ?? this.translation,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp,
    );
  }

  /// 从 AI 回复文本中分离英文和中文翻译
  /// AI 回复格式：英文内容\n[中文] 中文翻译
  static ({String english, String? chinese}) parseAiResponse(String rawText) {
    final marker = '[中文]';
    final idx = rawText.indexOf(marker);
    if (idx == -1) {
      return (english: rawText.trim(), chinese: null);
    }
    final english = rawText.substring(0, idx).trim();
    final chinese = rawText.substring(idx + marker.length).trim();
    return (english: english, chinese: chinese.isEmpty ? null : chinese);
  }
}

/// 对话会话信息（从 Edge Function 返回）
class ConversationSession {
  final String conversationId;
  final String wsUrl;
  final String apiKey;
  final String instructions;
  final String voice;
  final String model;
  final double costCny;
  final double balanceAfter;

  ConversationSession({
    required this.conversationId,
    required this.wsUrl,
    required this.apiKey,
    required this.instructions,
    required this.voice,
    required this.model,
    required this.costCny,
    required this.balanceAfter,
  });

  factory ConversationSession.fromJson(Map<String, dynamic> json) {
    return ConversationSession(
      conversationId: json['conversation_id'] as String,
      wsUrl: json['ws_url'] as String,
      apiKey: json['api_key'] as String,
      instructions: json['instructions'] as String,
      voice: json['voice'] as String? ?? 'Ethan',
      model: json['model'] as String? ?? 'qwen3.5-omni-plus-realtime',
      costCny: (json['cost_cny'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
    );
  }
}

/// 对话状态
enum ConversationState {
  idle,
  connecting,
  aiSpeaking,
  listening,
  processing,
  error,
  disconnected,
}

/// Realtime WebSocket 事件基类
sealed class RealtimeEvent {
  const RealtimeEvent();
}

/// 用户语音识别中间结果
class UserTranscriptionDelta extends RealtimeEvent {
  final String text;
  final String stash;
  const UserTranscriptionDelta(this.text, this.stash);
}

/// 用户语音识别完成
class UserTranscriptionCompleted extends RealtimeEvent {
  final String transcript;
  const UserTranscriptionCompleted(this.transcript);
}

/// AI 回复文本流
class AiTextDelta extends RealtimeEvent {
  final String delta;
  const AiTextDelta(this.delta);
}

/// AI 回复文本完成
class AiTextDone extends RealtimeEvent {
  final String transcript;
  const AiTextDone(this.transcript);
}

/// AI 回复音频流（Base64 PCM 24kHz）
class AiAudioDelta extends RealtimeEvent {
  final String base64Audio;
  const AiAudioDelta(this.base64Audio);
}

/// AI 回复音频完成
class AiAudioDone extends RealtimeEvent {
  const AiAudioDone();
}

/// AI 回复整体完成
class ResponseDone extends RealtimeEvent {
  const ResponseDone();
}

/// 错误事件
class RealtimeError extends RealtimeEvent {
  final String message;
  const RealtimeError(this.message);
}

/// 连接已建立
class ConnectionOpened extends RealtimeEvent {
  const ConnectionOpened();
}

/// 连接已关闭
class ConnectionClosed extends RealtimeEvent {
  final int? code;
  final String? reason;
  const ConnectionClosed(this.code, this.reason);
}
