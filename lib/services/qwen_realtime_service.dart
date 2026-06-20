import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:vidlang/models/conversation_message.dart';

/// Qwen-Omni-Realtime WebSocket 服务
/// 管理与千问实时模型的 WebSocket 连接，处理音频流收发和事件分发
class QwenRealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<RealtimeEvent> _eventController =
      StreamController<RealtimeEvent>.broadcast();

  bool _isConnected = false;
  int _eventIdCounter = 0;

  /// 事件流（供 Provider 监听）
  Stream<RealtimeEvent> get events => _eventController.stream;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 建立 WebSocket 连接
  Future<void> connect({
    required String wsUrl,
    required String apiKey,
  }) async {
    disconnect();

    final uri = Uri.parse(wsUrl);
    _channel = IOWebSocketChannel.connect(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
      protocols: const [],
    );

    _isConnected = true;
    _eventController.add(const ConnectionOpened());

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );
  }

  /// 配置会话（发送 session.update 事件）
  void updateSession({
    required String instructions,
    String voice = 'Ethan',
    String inputAudioFormat = 'pcm',
    String outputAudioFormat = 'pcm',
    double vadThreshold = 0.5,
    int silenceDurationMs = 800,
    String difficulty = 'intermediate',
  }) {
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'voice': voice,
        'input_audio_format': inputAudioFormat,
        'output_audio_format': outputAudioFormat,
        'instructions': '$instructions\n\n难度级别: $difficulty\n\n对话流程要求:\n1. AI先提出问题\n2. 等待用户回答\n3. 对用户回答给予评价和建议\n4. 根据评价提出下一个问题\n5. 重复以上流程\n\n注意事项:\n- 每次只问一个问题\n- 问题要符合用户的难度级别\n- 用户回答后要给予积极反馈\n- 适当纠正用户的语法错误\n- 保持对话自然流畅',
        'turn_detection': {
          'type': 'semantic_vad',
          'threshold': vadThreshold,
          'silence_duration_ms': silenceDurationMs,
        },
      },
    });
  }

  /// 发送音频数据（16kHz 单声道 PCM，Base64 编码）
  void sendAudio(Uint8List pcmData) {
    if (!_isConnected || pcmData.isEmpty) return;
    final base64Audio = base64Encode(pcmData);
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'input_audio_buffer.append',
      'audio': base64Audio,
    });
  }

  /// 取消当前 AI 回复
  void cancelResponse() {
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'response.cancel',
    });
  }

  /// 主动触发 AI 回复（用于让 AI 先开口说话）
  void initiateResponse() {
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'response.create',
    });
  }

  /// 断开连接
  void disconnect() {
    _isConnected = false;
    _subscription?.cancel();
    _subscription = null;
    if (_channel?.sink != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        // Ignore close errors
      }
    }
    _channel = null;
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _eventController.close();
  }

  // ─── 私有方法 ───

  void _sendEvent(Map<String, dynamic> event) {
    if (_channel?.sink == null) return;
    try {
      _channel!.sink.add(jsonEncode(event));
    } catch (e) {
      _eventController.add(RealtimeError('发送事件失败: $e'));
    }
  }

  String _nextEventId() {
    _eventIdCounter++;
    return 'event_$_eventIdCounter';
  }

  void _onMessage(dynamic message) {
    try {
      if (message is String) {
        final data = jsonDecode(message) as Map<String, dynamic>;
        _handleServerEvent(data);
      }
    } catch (e) {
      _eventController.add(RealtimeError('解析消息失败: $e'));
    }
  }

  void _handleServerEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';

    switch (type) {
      // ─── 会话相关 ───
      case 'session.created':
      case 'session.updated':
        // 会话已创建/更新，无需特殊处理
        break;

      // ─── 用户语音识别 ───
      case 'conversation.item.input_audio_transcription.delta':
        final text = data['text'] as String? ?? '';
        final stash = data['stash'] as String? ?? '';
        _eventController.add(UserTranscriptionDelta(text, stash));
        break;

      case 'conversation.item.input_audio_transcription.completed':
        final transcript = data['transcript'] as String? ?? '';
        _eventController.add(UserTranscriptionCompleted(transcript));
        break;

      // ─── AI 回复文本 ───
      case 'response.audio_transcript.delta':
        final delta = data['delta'] as String? ?? '';
        _eventController.add(AiTextDelta(delta));
        break;

      case 'response.audio_transcript.done':
        final transcript = data['transcript'] as String? ?? '';
        _eventController.add(AiTextDone(transcript));
        break;

      // 仅文本模式（modalities = ["text"]）时的文本 delta
      case 'response.text.delta':
        final delta = data['delta'] as String? ?? '';
        _eventController.add(AiTextDelta(delta));
        break;

      case 'response.text.done':
        final text = data['text'] as String? ?? '';
        _eventController.add(AiTextDone(text));
        break;

      // ─── AI 回复音频 ───
      case 'response.audio.delta':
        final delta = data['delta'] as String? ?? '';
        if (delta.isNotEmpty) {
          _eventController.add(AiAudioDelta(delta));
        }
        break;

      case 'response.audio.done':
        _eventController.add(const AiAudioDone());
        break;

      // ─── 响应生命周期 ───
      case 'response.created':
        // AI 开始响应
        break;

      case 'response.done':
        _eventController.add(const ResponseDone());
        break;

      case 'response.content_part.added':
      case 'response.content_part.done':
      case 'conversation.item.created':
      case 'conversation.item.truncated':
        // 内部事件，暂不处理
        break;

      // ─── VAD 相关 ───
      case 'input_audio_buffer.speech_started':
      case 'input_audio_buffer.speech_stopped':
      case 'input_audio_buffer.committed':
      case 'input_audio_buffer.cleared':
        // VAD/手动模式事件，暂不处理
        break;

      // ─── 错误 ───
      case 'error':
        final errorMsg = data['error']?['message'] as String? ?? '未知错误';
        _eventController.add(RealtimeError(errorMsg));
        break;

      default:
        // 未处理的事件类型
        break;
    }
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _eventController.add(RealtimeError('WebSocket 错误: $error'));
  }

  void _onDone() {
    _isConnected = false;
    _eventController.add(const ConnectionClosed(null, null));
  }
}
