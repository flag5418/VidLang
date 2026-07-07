import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/models/conversation_record.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
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
      
      // 根据难度构建 instructions
      final difficultyInstructions = _getDifficultyInstructions(difficulty);
      
      // 1. 通过 Edge Function 创建会话
      _session = await ConversationService.createSession(
        sourceType: sourceType, 
        sourceCode: sourceCode, 
        voice: voice, 
        difficulty: difficulty,
        difficultyInstructions: difficultyInstructions,
      );

      // 2. 建立 WebSocket 连接
      _realtimeService = QwenRealtimeService();
      await _realtimeService!.connect(wsUrl: _session!.wsUrl, apiKey: _session!.apiKey);

      // 3. 配置会话
      _realtimeService!.updateSession(
        instructions: _session!.instructions, 
        voice: _session!.voice,
        difficulty: difficulty,
      );

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

  /// 根据难度返回对应的指令
  String _getDifficultyInstructions(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return '使用简单词汇和短句，语速缓慢，多给鼓励。适合初学者。';
      case 'intermediate':
        return '使用适中难度的词汇和句子，适当给予纠正和建议。适合中级学习者。';
      case 'advanced':
        return '使用复杂词汇和专业表达，深入讨论话题。适合高级学习者。';
      default:
        return '使用适中难度的词汇和句子。适合中级学习者。';
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

    // 保存对话记录到本地数据库
    await _saveConversationRecord();

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

  /// 将当前对话保存到本地数据库
  Future<void> _saveConversationRecord() async {
    // 只在有实际对话内容时保存
    if (state.messages.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final difficulty = prefs.getString('app_difficulty_level') ?? 'intermediate';

      // 序列化消息列表
      final messagesData = state.messages.map((m) => {
        'id': m.id,
        'role': m.role.name,
        'text': m.text,
        'translation': m.translation,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList();

      // 取第一条消息作为预览
      String? preview;
      if (state.messages.isNotEmpty) {
        final firstMsg = state.messages.first;
        preview = firstMsg.text.length > 50
            ? '${firstMsg.text.substring(0, 50)}...'
            : firstMsg.text;
      }

      final record = ConversationRecord()
        ..sourceType = _sourceType ?? ''
        ..sourceCode = _sourceCode ?? ''
        ..sourceTitle = _sourceTitle
        ..voice = _session?.voice ?? 'Ethan'
        ..difficulty = difficulty
        ..turnCount = state.turnCount
        ..durationSeconds = state.duration.inSeconds
        ..remoteConversationId = _session?.conversationId
        ..messagesJson = jsonEncode(messagesData)
        ..firstMessagePreview = preview
        ..status = state.state == ConversationState.error ? 'error' : 'completed';

      await record.save();
    } catch (e) {
      print('保存对话记录失败: $e');
    }
  }

  /// 查询对话历史记录
  static Future<List<ConversationRecord>> getConversationHistory({
    String? sourceType,
    String? sourceCode,
    int limit = 50,
    int offset = 0,
  }) async {
    String? where;
    List<Object?> whereArgs = [];

    if (sourceType != null && sourceCode != null) {
      where = 'source_type = ? AND source_code = ? AND is_deleted = 0';
      whereArgs = [sourceType, sourceCode];
    } else if (sourceType != null) {
      where = 'source_type = ? AND is_deleted = 0';
      whereArgs = [sourceType];
    } else {
      where = 'is_deleted = 0';
    }

    return DatabaseService.findByCondition<ConversationRecord>(
      () => ConversationRecord(),
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 获取单条对话记录的详情（含解析后的消息）
  static Future<ConversationRecord?> getRecordDetail(String code) async {
    final db = await DatabaseService.database;
    final entity = ConversationRecord();
    final userCode = await DatabaseService.getCurrentUserCode();
    String whereClause = 'code = ? AND is_deleted = 0';
    List<Object?> whereArgs = [code];
    if (userCode != null) {
      whereClause += ' AND user_code = ?';
      whereArgs.add(userCode);
    }
    final maps = await db.query(
      entity.tableName,
      where: whereClause,
      whereArgs: whereArgs,
    );
    if (maps.isNotEmpty) {
      return entity.fromMap(maps.first) as ConversationRecord;
    }
    return null;
  }

  /// 删除对话记录
  static Future<bool> deleteConversationRecord(String code) async {
    try {
      final record = await getRecordDetail(code);
      if (record != null) {
        await record.softDelete();
        return true;
      }
      return false;
    } catch (e) {
      print('删除对话记录失败: $e');
      return false;
    }
  }

  /// 从历史记录恢复对话上下文
  /// 
  /// 基于之前的对话记录创建新会话，并加载历史消息作为上下文
  Future<void> resumeFromRecord(ConversationRecord record, {String voice = 'Ethan'}) async {
    if (state.state == ConversationState.connecting) return;

    // 解析历史消息
    final messagesData = record.parsedMessages;
    final restoredMessages = messagesData.map((m) {
      final role = m['role'] == 'ai' ? MessageRole.ai : MessageRole.user;
      return ConversationMessage(
        id: m['id'] as String?,
        role: role,
        text: m['text'] as String? ?? '',
        translation: m['translation'] as String?,
        timestamp: m['timestamp'] != null 
            ? DateTime.tryParse(m['timestamp'] as String) 
            : null,
      );
    }).toList();

    state = state.copyWith(
      state: ConversationState.connecting,
      messages: restoredMessages,
      errorMessage: null,
      sourceTitle: record.sourceTitle,
      turnCount: record.turnCount,
      duration: Duration(seconds: record.durationSeconds),
    );

    try {
      _sourceType = record.sourceType;
      _sourceCode = record.sourceCode;
      _sourceTitle = record.sourceTitle;
      
      // 创建新的会话（使用相同的来源）
      _session = await ConversationService.createSession(
        sourceType: record.sourceType, 
        sourceCode: record.sourceCode, 
        voice: voice, 
        difficulty: record.difficulty,
        difficultyInstructions: _getDifficultyInstructions(record.difficulty),
      );

      // 建立 WebSocket 连接
      _realtimeService = QwenRealtimeService();
      await _realtimeService!.connect(wsUrl: _session!.wsUrl, apiKey: _session!.apiKey);

      // 构建包含历史上下文的 instructions
      final contextInstructions = _buildContextInstructions(record);
      
      // 配置会话（注入历史上下文）
      _realtimeService!.updateSession(
        instructions: contextInstructions, 
        voice: _session!.voice,
        difficulty: record.difficulty,
      );

      // 监听事件
      _eventSubscription = _realtimeService!.events.listen(_handleEvent);

      // 触发 AI 继续对话（基于上下文）
      await Future.delayed(const Duration(milliseconds: 500));
      _realtimeService!.initiateResponse();

      // 初始化音频设备
      _recorder = AudioRecorder();
      _audioPlayer = AudioPlayer();
      _playerCompleteSubscription = _audioPlayer!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        if (_audioBuffer.isNotEmpty) {
          _playAudioBuffer();
        }
      });

      // 启动计时器
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

  /// 构建包含历史对话上下文的 instructions
  /// 将之前的对话摘要附加到系统指令中，让 AI 能够延续话题
  String _buildContextInstructions(ConversationRecord record) {
    final baseInstructions = _session?.instructions ?? '';
    
    // 构建对话摘要
    final messagesData = record.parsedMessages;
    final buffer = StringBuffer();
    buffer.writeln('## Previous Conversation Context');
    buffer.writeln('The student has previously discussed the following topic. Continue the conversation naturally based on this context.');
    buffer.writeln('');
    
    // 只取最近 N 轮对话作为上下文（避免过长）
    final maxContextTurns = 10;
    final recentMessages = messagesData.length > maxContextTurns * 2
        ? messagesData.sublist(messagesData.length - maxContextTurns * 2)
        : messagesData;
    
    for (final msg in recentMessages) {
      final role = msg['role'] == 'ai' ? 'Tutor' : 'Student';
      final text = msg['text'] as String? ?? '';
      buffer.writeln('$role: $text');
    }
    
    buffer.writeln('');
    buffer.writeln('Please respond naturally to continue this conversation. You may ask a follow-up question or provide feedback on the previous discussion.');
    
    return '$baseInstructions\n\n${buffer.toString()}';
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
        // 连接关闭时，如果不是主动结束，则保持当前状态或转为listening
        // 只有在明确结束对话时才设置为disconnected
        if (state.state != ConversationState.disconnected) {
          // 如果是意外断开，尝试恢复到listening状态等待重连
          state = state.copyWith(state: ConversationState.listening);
        }
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
