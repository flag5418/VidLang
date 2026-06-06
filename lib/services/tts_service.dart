import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_tts/flutter_tts.dart';

import 'package:vidlang/config.dart';
import 'package:vidlang/services/aliyun_tts_service.dart';

/// 跨平台 TTS 朗读服务
///
/// 提供两种 TTS 引擎：
/// - 系统 TTS：使用 flutter_tts（免费、离线），适用于基本朗读
/// - 阿里云 TTS：使用 AliyunTtsService（高质量、流式），适用于"清晰朗读"
///
/// 当阿里云 API Key 已配置时，"清晰朗读"会自动使用阿里云 TTS；
/// 否则降级为系统 TTS。
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _initialized = false;
  bool _isSpeaking = false;

  /// 阿里云 TTS 引擎
  final AliyunTtsService _aliTts = AliyunTtsService();

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 阿里云 API Key 是否已配置
  bool get hasAliyunConfig => AppConfig.aliDashScopeApiKey.isNotEmpty;

  /// 初始化系统 TTS
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _flutterTts = FlutterTts();
      _flutterTts!.setCompletionHandler(() => _isSpeaking = false);
      _flutterTts!.setErrorHandler((_) => _isSpeaking = false);
      _flutterTts!.setCancelHandler(() => _isSpeaking = false);
      _initialized = true;
    } catch (e) {
      print('TTS init error: $e');
    }
  }

  /// 使用系统 TTS 朗读文本
  Future<bool> speak({
    required String text,
    String language = 'en-US',
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (text.isEmpty) return false;
    await initialize();
    if (_flutterTts == null) return false;

    try {
      await _flutterTts!.setLanguage(language);
      await _flutterTts!.setSpeechRate(rate);
      await _flutterTts!.setPitch(pitch);
      await _flutterTts!.setVolume(volume);
      _isSpeaking = true;
      final result = await _flutterTts!.speak(text);
      return result == 1;
    } catch (e) {
      print('TTS speak error: $e');
      _isSpeaking = false;
      return false;
    }
  }

  /// 清晰朗读 — 优先使用阿里云 TTS（高质量），无配置则降级为系统 TTS
  ///
  /// 阿里云 TTS 模式下，使用 [audioPlayer] 播放下载后保存的音频文件。
  /// 阿里云 TTS 需要 [audioPlayer] 参数，系统模式无需。
  Future<void> speakClarity({
    required String text,
    ap.AudioPlayer? audioPlayer,
    FutureOr<void> Function()? onComplete,
  }) async {
    if (text.isEmpty) return;

    if (hasAliyunConfig && audioPlayer != null) {
      // 阿里云 TTS：下载并播放
      final path = await _aliTts.getAudioPath(text);
      if (path != null && await File(path).exists()) {
        await audioPlayer.stop();
        await audioPlayer.play(ap.DeviceFileSource(path));
        if (onComplete != null) {
          audioPlayer.onPlayerComplete.first.then((_) => onComplete());
        }
      } else {
        // 下载失败，降级到系统 TTS
        await speakSubtitle(text);
        if (onComplete != null) onComplete();
      }
    } else {
      // 系统 TTS
      await speakSubtitle(text);
      if (onComplete != null) onComplete();
    }
  }

  /// 朗读字幕（适用于视频播放器中逐句朗读）
  Future<bool> speakSubtitle(String text) async {
    return speak(text: text, language: 'en-US', rate: 0.45, pitch: 1.0);
  }

  /// 朗读单词（慢速、清晰）
  Future<bool> speakWord(String word) async {
    return speak(text: word, language: 'en-US', rate: 0.3, pitch: 1.0);
  }

  /// 停止朗读
  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
      await _aliTts.cancel();
    } catch (_) {}
    _isSpeaking = false;
  }

  /// 暂停朗读
  Future<void> pause() async {
    try {
      await _flutterTts?.pause();
    } catch (_) {}
  }

  /// 是否正在朗读
  bool get isSpeaking => _isSpeaking;

  /// 获取可用语言列表
  Future<List<String>> getLanguages() async {
    await initialize();
    if (_flutterTts == null) return [];
    try {
      return (await _flutterTts!.getLanguages).cast<String>();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    stop();
    _flutterTts = null;
    _initialized = false;
  }
}
