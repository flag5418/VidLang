import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  ///
  /// 使用 dart:io 的 WebSocket.connect 方法，支持自定义 headers。
  /// DashScope 认证要求：Authorization: Bearer DASHSCOPE_API_KEY
  Future<void> connect({
    required String wsUrl,
    required String apiKey,
  }) async {
    disconnect();

    final uri = Uri.parse(wsUrl);

    // 使用 dart:io 的 WebSocket.connect，支持自定义 headers
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    _channel = IOWebSocketChannel(socket);

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
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcmData),
    });
  }

  /// 提交音频缓冲区（手动模式下需要调用）
  void commitAudio() {
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'input_audio_buffer.commit',
    });
  }

  /// 触发 AI 生成响应
  void initiateResponse() {
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'response.create',
    });
  }

  /// 取消当前响应
  void cancelResponse() {
    _sendEvent({
      'event_id': _nextEventId(),
      'type': 'response.cancel',
    });
  }

  /// 发送客户端事件
  void _sendEvent(Map<String, dynamic> event) {
    if (_channel == null) return;
    final json = jsonEncode(event);
    _channel!.sink.add(json);
  }

  String _nextEventId() {
    _eventIdCounter++;
    return 'event_${_eventIdCounter.toString().padLeft(3, '0')}';
  }

  /// 处理服务端消息
  void _onMessage(dynamic message) {
    if (message is! String) return;

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      switch (type) {
        case 'session.created':
        case 'session.updated':
          // 会话配置确认
          break;

        case 'input_audio_buffer.speech_started':
          // 检测到语音开始
          break;

        case 'input_audio_buffer.speech_stopped':
          // 检测到语音结束
          break;

        case 'input_audio_buffer.committed':
          // 音频已提交
          break;

        case 'response.created':
          // 响应开始生成
          break;

        case 'response.text.delta':
          final delta = data['delta'] as String? ?? '';
          _eventController.add(AiTextDelta(delta));
          break;

        case 'response.text.done':
          final transcript = data['text'] as String? ?? '';
          _eventController.add(AiTextDone(transcript));
          break;

        case 'response.audio.delta':
          final base64Audio = data['delta'] as String? ?? '';
          _eventController.add(AiAudioDelta(base64Audio));
          break;

        case 'response.audio.done':
          _eventController.add(const AiAudioDone());
          break;

        case 'response.done':
          _eventController.add(const ResponseDone());
          break;

        case 'conversation.item.input_audio_transcription.delta':
          final text = data['delta'] as String? ?? '';
          _eventController.add(UserTranscriptionDelta(text, text));
          break;

        case 'conversation.item.input_audio_transcription.completed':
          final transcript = data['transcript'] as String? ?? '';
          _eventController.add(UserTranscriptionCompleted(transcript));
          break;

        case 'error':
          final errorMsg = data['error']?['message'] as String? ?? '未知错误';
          _eventController.add(RealtimeError(errorMsg));
          break;

        default:
          // 忽略未知事件类型
          break;
      }
    } catch (e) {
      _eventController.add(RealtimeError('消息解析错误: $e'));
    }
  }

  void _onError(Object error) {
    _isConnected = false;
    _eventController.add(RealtimeError(error.toString()));
  }

  void _onDone() {
    _isConnected = false;
    _eventController.add(const ConnectionClosed(null, null));
  }

  /// 断开连接
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
