import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/unified_tts_service.dart';

/// 跨平台 TTS 朗读服务
///
/// 统一通过 UnifiedTtsService 调用：
/// - 免费模式 → 本地 Supertonic TTS
/// - 收费模式 → 阿里云 TTS（Edge Function）
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool _isSpeaking = false;

  /// 使用当前订阅模式朗读文本
  Future<void> speakClarity({
    required String text,
    SubscriptionMode? mode,
    FutureOr<void> Function()? onComplete,
  }) async {
    if (text.isEmpty) {
      if (onComplete != null) onComplete();
      return;
    }

    final targetMode = mode ?? SubscriptionMode.free;
    try {
      final result = await UnifiedTtsService.instance.synthesize(text: text, mode: targetMode);
      if (result.success && result.audioPath.isNotEmpty) {
        final player = ap.AudioPlayer();
        await player.play(ap.DeviceFileSource(result.audioPath));
        await player.onPlayerComplete.first;
        try {
          await File(result.audioPath).delete();
        } catch (_) {}
        if (onComplete != null) onComplete();
        return;
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }

    if (onComplete != null) onComplete();
  }

  /// 朗读单词（慢速、清晰）
  Future<void> speakWord(String word, {SubscriptionMode? mode, FutureOr<void> Function()? onComplete}) async {
    await speakClarity(text: word, mode: mode, onComplete: onComplete);
  }

  /// 朗读字幕（适用于视频播放器中逐句朗读）
  Future<void> speakSubtitle(String text, {SubscriptionMode? mode, FutureOr<void> Function()? onComplete}) async {
    await speakClarity(text: text, mode: mode, onComplete: onComplete);
  }

  /// 停止朗读
  Future<void> stop() async {
    _isSpeaking = false;
  }

  /// 是否正在朗读
  bool get isSpeaking => _isSpeaking;
}
