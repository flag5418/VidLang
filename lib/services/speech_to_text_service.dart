import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// 免费模式下使用的语音识别服务（基于系统原生 API）
///
/// iOS: SFSpeechRecognizer
/// Android: SpeechRecognizer (需要 Google 服务)
class SpeechToTextService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final SpeechToTextService _instance = SpeechToTextService._internal();

  factory SpeechToTextService() => _instance;

  SpeechToTextService._internal();

  bool _isAvailable = false;
  bool _isListening = false;
  final StreamController<String> _textStream = StreamController<String>.broadcast();
  final StreamController<bool> _statusStream = StreamController<bool>.broadcast();

  Stream<String> get textStream => _textStream.stream;
  Stream<bool> get statusStream => _statusStream.stream;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  /// 初始化并检查语音识别是否可用
  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      _statusStream.add(_isAvailable);
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      _statusStream.add(false);
      return false;
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'done') {
      _isListening = false;
    }
  }

  void _onError(SpeechRecognitionError error) {
    _isListening = false;
    if (error.errorMsg.contains('not_allowed')) {
      _isAvailable = false;
      _statusStream.add(false);
    }
  }

  /// 开始语音识别
  /// [localeId] 语言标识，如 'en-US'
  Future<bool> start({String localeId = 'en-US'}) async {
    if (!_isAvailable || _isListening) return false;

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 5),
          localeId: localeId,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      _statusStream.add(true);
      return true;
    } catch (e) {
      _isListening = false;
      return false;
    }
  }

  /// 停止语音识别
  Future<void> stop() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
      _isListening = false;
      _statusStream.add(false);
    } catch (e) {
      _isListening = false;
    }
  }

  /// 取消识别
  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _statusStream.add(false);
    } catch (e) {
      _isListening = false;
    }
  }

  /// 释放资源
  void dispose() {
    _textStream.close();
    _statusStream.close();
    _speech.cancel();
    _isListening = false;
  }

  void _onResult(SpeechRecognitionResult result) {
    _textStream.add(result.recognizedWords);
  }
}
