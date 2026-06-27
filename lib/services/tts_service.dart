import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/local_ai_service.dart';

/// 跨平台 TTS 朗读服务
///
/// 提供三种 TTS 引擎：
/// - 本地 Piper TTS：使用 sherpa-onnx（高质量、离线），优先使用
/// - 阿里云 TTS：通过 Edge Function 调用（避免客户端暴露 API Key）
/// - 系统 TTS：最终回退
///
/// 优先级：本地 Piper TTS > 阿里云 TTS（Edge Function）> 系统 TTS
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool _isSpeaking = false;

  /// 本地 AI 服务（用于 Piper TTS）
  final LocalAiService _localAi = LocalAiService.instance;

  /// 是否可以使用本地 Piper TTS
  bool get canUseLocalTts => _localAi.canUseFeature(LocalAiFeature.tts);

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

  /// 清晰朗读 — 优先使用本地 Piper TTS，其次阿里云 TTS（Edge Function），最后系统 TTS
  ///
  /// [useAliyun] 是否使用阿里云 TTS，默认 true。免费模式下应设为 false
  /// 阿里云 TTS 模式下，使用 [audioPlayer] 播放下载后保存的音频文件。
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

      // 其次使用阿里云 TTS（通过 Edge Function）
      if (useAliyun && audioPlayer != null) {
        final ttsResult = await AiService.getTtsAudio(text: text);
        if (ttsResult != null) {
          final audioBase64 = ttsResult['audioBase64'] as String?;
          final format = ttsResult['format'] as String? ?? 'mp3';
          
          if (audioBase64 != null && audioBase64.isNotEmpty) {
            // 将 base64 保存为临时文件并播放
            final tempDir = await getTemporaryDirectory();
            final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.$format';
            final tempPath = '${tempDir.path}/$fileName';
            
            final audioBytes = base64Decode(audioBase64);
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(audioBytes);
            
            await audioPlayer.stop();
            await audioPlayer.play(ap.DeviceFileSource(tempPath));
            if (onComplete != null) {
              audioPlayer.onPlayerComplete.first.then((_) => onComplete());
            }
            return;
          }
        }
      }

      // 最后回退到系统 TTS
      debugPrint('本地和阿里云 TTS 均不可用，尝试使用系统 TTS');
      final flutterTts = FlutterTts();
      await flutterTts.setLanguage('en-US');
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak(text);
      
      // 系统 TTS 没有完成回调，使用延迟模拟
      Future.delayed(Duration(milliseconds: text.length * 80 + 500), () {
        if (onComplete != null) onComplete();
      });
    } catch (_) {
      if (onComplete != null) onComplete();
    }
  }

  /// 朗读单词（慢速、清晰）
  Future<bool> speakWord(String word) async {
    return speakWithLocalPiper(text: word);
  }

  /// 朗读字幕（适用于视频播放器中逐句朗读）
  Future<bool> speakSubtitle(String text) async {
    return speakWithLocalPiper(text: text);
  }

  /// 停止朗读
  Future<void> stop() async {
    _isSpeaking = false;
  }

  /// 是否正在朗读
  bool get isSpeaking => _isSpeaking;
}
