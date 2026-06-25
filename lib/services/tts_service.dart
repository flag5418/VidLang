import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:vidlang/config.dart';
import 'package:vidlang/services/aliyun_tts_service.dart';
import 'package:vidlang/services/local_ai_service.dart';

/// 跨平台 TTS 朗读服务
///
/// 提供三种 TTS 引擎：
/// - 本地 Piper TTS：使用 sherpa-onnx（高质量、离线），优先使用
/// - 系统 TTS：使用 flutter_tts（免费、离线），作为降级方案
/// - 阿里云 TTS：使用 AliyunTtsService（高质量、流式），适用于"清晰朗读"
///
/// 优先级：本地 Piper TTS > 系统 TTS > 阿里云 TTS
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _initialized = false;
  bool _isSpeaking = false;

  /// 阿里云 TTS 引擎
  final AliyunTtsService _aliTts = AliyunTtsService();

  /// 本地 AI 服务（用于 Piper TTS）
  final LocalAiService _localAi = LocalAiService.instance;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 阿里云 API Key 是否已配置
  bool get hasAliyunConfig => AppConfig.aliDashScopeApiKey.isNotEmpty;

  /// 是否可以使用本地 Piper TTS
  bool get canUseLocalTts => _localAi.canUseFeature(LocalAiFeature.tts);

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
      debugPrint('TTS init error: $e');
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
      debugPrint('TTS speak error: $e');
      _isSpeaking = false;
      return false;
    }
  }

  /// 使用本地 Piper TTS 朗读文本
  Future<bool> speakWithLocalPiper({
    required String text,
    String language = 'en-US',
  }) async {
    if (text.isEmpty) return false;
    if (!canUseLocalTts) return false;

    try {
      _isSpeaking = true;
      
      // 生成音频文件
      final audioPath = await _localAi.synthesizeToFile(
        text: text,
        outputPath: '', // 自动生成临时路径
      );
      
      if (audioPath == null || !await File(audioPath).exists()) {
        _isSpeaking = false;
        return false;
      }
      
      // 播放音频
      final player = ap.AudioPlayer();
      await player.play(ap.DeviceFileSource(audioPath));
      
      // 等待播放完成
      await player.onPlayerComplete.first;
      _isSpeaking = false;
      
      // 清理临时文件
      try {
        await File(audioPath).delete();
      } catch (_) {}
      
      return true;
    } catch (e) {
      debugPrint('Local Piper TTS speak error: $e');
      _isSpeaking = false;
      return false;
    }
  }

  /// 清晰朗读 — 优先级：本地 Piper TTS > 阿里云 TTS > 系统 TTS
  ///
  /// [useAliyun] 是否使用阿里云 TTS，默认 true。免费模式下应设为 false
  /// 阿里云 TTS 模式下，使用 [audioPlayer] 播放下载后保存的音频文件。
  /// 阿里云 TTS 需要 [audioPlayer] 参数，系统模式无需。
  Future<void> speakClarity({
    required String text,
    ap.AudioPlayer? audioPlayer,
    FutureOr<void> Function()? onComplete,
    bool useAliyun = true,
  }) async {
    if (text.isEmpty) {
      if (onComplete != null) onComplete();
      return;
    }

    try {
      // 优先使用本地 Piper TTS
      if (canUseLocalTts) {
        final success = await speakWithLocalPiper(text: text);
        if (success) {
          if (onComplete != null) onComplete();
          return;
        }
      }

      // 其次使用阿里云 TTS
      if (useAliyun && hasAliyunConfig && audioPlayer != null) {
        // 阿里云 TTS：下载并播放
        final path = await _aliTts.getAudioPath(text);
        if (path != null && await File(path).exists()) {
          await audioPlayer.stop();
          await audioPlayer.play(ap.DeviceFileSource(path));
          if (onComplete != null) {
            audioPlayer.onPlayerComplete.first.then((_) => onComplete());
          }
          return;
        }
        // 下载失败，降级到系统 TTS（走下方逻辑）
      }

      // 系统 TTS：等待朗读真正结束后再触发 onComplete
      await initialize();
      if (_flutterTts == null) {
        if (onComplete != null) onComplete();
        return;
      }

      final completer = Completer<void>();
      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        if (!completer.isCompleted) completer.complete();
      });
      _flutterTts!.setErrorHandler((_) {
        _isSpeaking = false;
        if (!completer.isCompleted) completer.complete();
      });
      _flutterTts!.setCancelHandler(() {
        _isSpeaking = false;
        if (!completer.isCompleted) completer.complete();
      });

      await speakSubtitle(text);
      await completer.future;
      if (onComplete != null) onComplete();
    } catch (_) {
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
