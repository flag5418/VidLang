import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/qwen_realtime_service.dart';

/// 对话状态数据
class ConversationStateData {
  final ConversationState state;
  final List<ConversationMessage> messages;
  final String? errorMessage;
  final String? sourceTitle;
  final bool showTranslation; // 字幕对话开关
  final int turnCount;
  final Duration duration;
  final String? userTranscriptionPreview; // 用户语音识别中间态

  const ConversationStateData({
    this.state = ConversationState.idle,
    this.messages = const [],
    this.errorMessage,
    this.sourceTitle,
    this.showTranslation = true,
    this.turnCount = 0,
    this.duration = Duration.zero,
    this.userTranscriptionPreview,
  });

  ConversationStateData copyWith({
    ConversationState? state,
    List<ConversationMessage>? messages,
    String? errorMessage,
    String? sourceTitle,
    bool? showTranslation,
    int? turnCount,
    Duration? duration,
    String? userTranscriptionPreview,
  }) {
    return ConversationStateData(
      state: state ?? this.state,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      showTranslation: showTranslation ?? this.showTranslation,
      turnCount: turnCount ?? this.turnCount,
      duration: duration ?? this.duration,
      userTranscriptionPreview: userTranscriptionPreview ?? this.userTranscriptionPreview,
    );
  }
}

final conversationProvider = StateNotifierProvider<ConversationNotifier, ConversationStateData>((ref) {
  return ConversationNotifier();
});

class ConversationNotifier extends StateNotifier<ConversationStateData> {
  QwenRealtimeService? _realtimeService;
  AudioRecorder? _recorder;
  AudioPlayer? _audioPlayer;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _eventSubscription;
  Timer? _durationTimer;
  DateTime? _sessionStartTime;

  ConversationSession? _session;
  String? _currentAiMessageId;
  String _aiTextBuffer = '';
  bool _isRecording = false;
  StreamSubscription? _recorderStream;
  int? _currentTurnIndex;
  bool _answerBilledForTurn = false;
  String? _sourceType;
  String? _sourceCode;
  String? _sourceTitle;

  // 音频播放缓冲区
  final List<int> _audioBuffer = [];
  bool _isPlaying = false;

  ConversationNotifier() : super(const ConversationStateData());

  /// 开始对话
  Future<void> startConversation({required String sourceType, required String sourceCode, String? sourceTitle, String voice = 'Ethan'}) async {
    if (state.state == ConversationState.connecting) return;

    // 读取用户设置的学习难度
    final prefs = await SharedPreferences.getInstance();
    final difficulty = prefs.getString('app_difficulty_level') ?? 'intermediate';

    state = state.copyWith(
      state: ConversationState.connecting,
      messages: [],
      errorMessage: null,
      sourceTitle: sourceTitle,
      turnCount: 0,
      duration: Duration.zero,
    );

    try {
      _sourceType = sourceType;
      _sourceCode = sourceCode;
      _sourceTitle = sourceTitle;
      // 1. 通过 Edge Function 创建会话
      _session = await ConversationService.createSession(sourceType: sourceType, sourceCode: sourceCode, voice: voice, difficulty: difficulty);

      // 2. 建立 WebSocket 连接
      _realtimeService = QwenRealtimeService();
      await _realtimeService!.connect(wsUrl: _session!.wsUrl, apiKey: _session!.apiKey);

      // 3. 配置会话
      _realtimeService!.updateSession(instructions: _session!.instructions, voice: _session!.voice);

      // 4. 监听事件
      _eventSubscription = _realtimeService!.events.listen(_handleEvent);

      // 5. 触发 AI 先说话（等待 session.update 确认后发送 response.create）
      await Future.delayed(const Duration(milliseconds: 500));
      _realtimeService!.initiateResponse();

      // 6. 初始化音频设备
      _recorder = AudioRecorder();
      _audioPlayer = AudioPlayer();
      _playerCompleteSubscription = _audioPlayer!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        if (_audioBuffer.isNotEmpty) {
          _playAudioBuffer();
        }
      });

      // 7. 启动计时器
      _sessionStartTime = DateTime.now();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_sessionStartTime != null) {
          state = state.copyWith(duration: DateTime.now().difference(_sessionStartTime!));
        }
      });

      state = state.copyWith(state: ConversationState.listening);
    } catch (e) {
      state = state.copyWith(state: ConversationState.error, errorMessage: e.toString());
    }
  }

  /// 开始录音
  Future<void> startRecording() async {
    if (_isRecording || _recorder == null) return;
    if (state.state == ConversationState.aiSpeaking) {
      // 打断 AI 说话
      _realtimeService?.cancelResponse();
      _stopAudioPlayback();
    }

    try {
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(state: ConversationState.error, errorMessage: '没有麦克风权限');
        return;
      }

      // 配置 16kHz 单声道 PCM，使用 startStream 获取音频流
      final recordStream = await _recorder!.startStream(
        const RecordConfig(
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000, // 16kHz * 16bit = 256kbps
        ),
      );

      _isRecording = true;
      state = state.copyWith(state: ConversationState.listening);

      // 监听录音流，发送音频到 WebSocket
      _recorderStream = recordStream.listen((data) {
        if (_realtimeService?.isConnected == true) {
          _realtimeService!.sendAudio(Uint8List.fromList(data));
        }
      });
    } catch (e) {
      print('startRecording error: $e');
    }
  }

  /// 停止录音
  Future<void> stopRecording() async {
    if (!_isRecording || _recorder == null) return;
    _isRecording = false;

    try {
      await _recorderStream?.cancel();
      _recorderStream = null;
      await _recorder!.stop();
    } catch (e) {
      print('stopRecording error: $e');
    }
  }

  /// 切换字幕对话开关
  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  /// 结束对话
  Future<void> endConversation() async {
    await stopRecording();
    _stopAudioPlayback();

    _eventSubscription?.cancel();
    _eventSubscription = null;

    _durationTimer?.cancel();
    _durationTimer = null;

    _realtimeService?.disconnect();
    _realtimeService?.dispose();
    _realtimeService = null;

    _recorder?.dispose();
    _recorder = null;

    _audioPlayer?.dispose();
    _audioPlayer = null;
    await _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = null;

    // 结算
    if (_session != null) {
      await ConversationService.settleSession(
        conversationId: _session!.conversationId,
        turnCount: state.turnCount,
        durationSeconds: state.duration.inSeconds,
        sourceType: _sourceType,
        sourceCode: _sourceCode,
        sourceTitle: _sourceTitle,
      );
    }

    state = state.copyWith(state: ConversationState.disconnected);
  }

  @override
  void dispose() {
    endConversation();
    super.dispose();
  }

  // ─── 事件处理 ───

  void _handleEvent(RealtimeEvent event) {
    switch (event) {
      case ConnectionOpened():
        // 连接已建立，等待 session.update 确认
        break;

      case UserTranscriptionDelta():
        // 用户语音识别中间结果
        state = state.copyWith(userTranscriptionPreview: event.text + event.stash);
        break;

      case UserTranscriptionCompleted():
        // 用户语音识别完成 → 添加用户消息
        final transcript = event.transcript.trim();
        if (transcript.isEmpty) break;
        final nextTurn = state.turnCount + 1;

        state = state.copyWith(
          userTranscriptionPreview: null,
          messages: [
            ...state.messages,
            ConversationMessage(role: MessageRole.user, text: transcript),
          ],
          turnCount: nextTurn,
        );
        _currentTurnIndex = nextTurn;
        _answerBilledForTurn = false;
        final conversationId = _session?.conversationId;
        if (conversationId != null) {
          ConversationService.billTurn(
            conversationId: conversationId,
            turnIndex: nextTurn,
            isQuestion: true,
            sourceType: _sourceType,
            sourceCode: _sourceCode,
            sourceTitle: _sourceTitle,
          ).catchError((e) {
            state = state.copyWith(state: ConversationState.error, errorMessage: e.toString());
          });
        }
        break;

      case AiTextDelta():
        // AI 回复文本流式输出
        _aiTextBuffer += event.delta;

        if (_currentAiMessageId == null) {
          // 创建新的 AI 消息
          final msg = ConversationMessage(role: MessageRole.ai, text: _aiTextBuffer, isStreaming: true);
          _currentAiMessageId = msg.id;
          state = state.copyWith(state: ConversationState.aiSpeaking, messages: [...state.messages, msg]);
        } else {
          // 更新现有消息
          _updateAiMessage(_aiTextBuffer);
        }
        break;

      case AiTextDone():
        // AI 回复文本完成 → 解析英文和翻译
        final parsed = ConversationMessage.parseAiResponse(_aiTextBuffer);
        if (_currentAiMessageId != null) {
          _updateAiMessage(parsed.english, translation: parsed.chinese, isStreaming: false);
        }
        _currentAiMessageId = null;
        _aiTextBuffer = '';
        break;

      case AiAudioDelta():
        // AI 回复音频流 → 缓冲并播放
        _enqueueAudio(event.base64Audio);
        break;

      case AiAudioDone():
        // 音频生成完成
        break;

      case ResponseDone():
        // AI 回复整体完成 → 切回 listening
        final conversationId = _session?.conversationId;
        final turnIndex = _currentTurnIndex;
        if (conversationId != null && turnIndex != null && !_answerBilledForTurn) {
          _answerBilledForTurn = true;
          ConversationService.billTurn(
            conversationId: conversationId,
            turnIndex: turnIndex,
            isQuestion: false,
            sourceType: _sourceType,
            sourceCode: _sourceCode,
            sourceTitle: _sourceTitle,
          ).catchError((e) {
            state = state.copyWith(state: ConversationState.error, errorMessage: e.toString());
          });
        }
        _currentAiMessageId = null;
        _aiTextBuffer = '';
        if (state.state == ConversationState.aiSpeaking || state.state == ConversationState.processing) {
          state = state.copyWith(state: ConversationState.listening);
        }
        break;

      case RealtimeError():
        state = state.copyWith(state: ConversationState.error, errorMessage: event.message);
        break;

      case ConnectionClosed():
        state = state.copyWith(state: ConversationState.disconnected);
        break;
    }
  }

  void _updateAiMessage(String text, {String? translation, bool? isStreaming}) {
    final messages = List<ConversationMessage>.from(state.messages);
    final idx = messages.indexWhere((m) => m.id == _currentAiMessageId);
    if (idx >= 0) {
      messages[idx] = messages[idx].copyWith(text: text, translation: translation, isStreaming: isStreaming);
      state = state.copyWith(messages: messages);
    }
  }

  // ─── 音频播放 ───

  void _enqueueAudio(String base64Audio) {
    try {
      final bytes = _base64ToBytes(base64Audio);
      _audioBuffer.addAll(bytes);

      // 每积累约 2400 bytes（100ms @ 24kHz 16bit）播放一次
      if (!_isPlaying && _audioBuffer.length >= 2400) {
        _playAudioBuffer();
      }
    } catch (e) {
      print('audio decode error: $e');
    }
  }

  Future<void> _playAudioBuffer() async {
    if (_audioBuffer.isEmpty || _audioPlayer == null) return;
    _isPlaying = true;

    try {
      // 取出当前缓冲区数据
      final data = Uint8List.fromList(_audioBuffer);
      _audioBuffer.clear();

      final wavBytes = _pcmToWav(data, sampleRate: 24000, channels: 1, bitsPerSample: 16);
      await _audioPlayer!.setSourceBytes(wavBytes, mimeType: 'audio/wav');
      await _audioPlayer!.resume();
    } catch (e) {
      _isPlaying = false;
      print('audio playback error: $e');
    }
  }

  Uint8List _pcmToWav(Uint8List pcm, {required int sampleRate, required int channels, required int bitsPerSample}) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataLength = pcm.lengthInBytes;
    final riffChunkSize = 36 + dataLength;

    final header = ByteData(44);
    header.setUint32(0, 0x46464952, Endian.little);
    header.setUint32(4, riffChunkSize, Endian.little);
    header.setUint32(8, 0x45564157, Endian.little);
    header.setUint32(12, 0x20746d66, Endian.little);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint32(36, 0x61746164, Endian.little);
    header.setUint32(40, dataLength, Endian.little);

    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  void _stopAudioPlayback() {
    _audioBuffer.clear();
    _isPlaying = false;
    _audioPlayer?.stop();
  }

  List<int> _base64ToBytes(String base64Str) {
    try {
      return base64Decode(base64Str);
    } catch (e) {
      return [];
    }
  }
}
