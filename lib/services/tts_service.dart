import 'dart:async';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/dashscope_tts_service.dart';
import 'package:vidlang/services/local_tts_service.dart';
import 'package:vidlang/services/unified_tts_service.dart';

/// TTS 事件回调
///
/// 用于向调用方通知 TTS 状态变化，便于 UI 即时反馈。
class TtsEvent {
  /// 事件类型
  final TtsEventType type;

  /// 附加消息（如错误信息）
  final String? message;

  const TtsEvent({required this.type, this.message});

  const TtsEvent.loading()
      : type = TtsEventType.loading,
        message = null;

  const TtsEvent.playing()
      : type = TtsEventType.playing,
        message = null;

  const TtsEvent.completed()
      : type = TtsEventType.completed,
        message = null;

  const TtsEvent.error(String msg)
      : type = TtsEventType.error,
        message = msg;
}

/// TTS 事件类型
enum TtsEventType {
  /// 开始加载（云端合成中）
  loading,

  /// 开始播放（音频就绪）
  playing,

  /// 播放完成
  completed,

  /// 发生错误
  error,
}

/// 跨平台 TTS 朗读服务
///
/// 统一通过 UnifiedTtsService 调用：
/// - 免费模式 → 原生系统 TTS（iOS AVSpeechSynthesizer / Android TTS）
/// - 收费模式 → 阿里云 TTS（PCM 流式播放，低延迟）
///
/// 性能优化：
/// - 云端 TTS 结果持久化到 Documents/tts_cache/，重复点击同一句秒开
/// - 缓存文件名基于文本 SHA256 hash，跨进程复用
/// - 支持 onEvent 回调，UI 可立即显示 loading 状态
/// - 支持预加载（prefetch），提前合成下一句
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool _isSpeaking = false;

  /// 复用同一个 AudioPlayer 实例，避免 flutter_pcm_player 索引越界
  final ap.AudioPlayer _player = ap.AudioPlayer();

  /// 是否正在朗读
  bool get isSpeaking => _isSpeaking;

  /// 使用当前订阅模式朗读文本
  ///
  /// [onEvent] 可选的事件回调，用于 UI 即时反馈：
  ///   - loading: 开始合成音频（云端模式下用户会看到等待状态）
  ///   - playing: 音频开始播放
  ///   - completed: 播放结束
  ///   - error: 发生错误
  ///
  /// [onComplete] 播放完成的最终回调（兼容旧接口）
  Future<void> speakClarity({
    required String text,
    SubscriptionMode? mode,
    void Function(TtsEvent)? onEvent,
    FutureOr<void> Function()? onComplete,
    void Function(double fraction)? onProgress,
  }) async {
    if (text.isEmpty) {
      onEvent?.call(const TtsEvent.completed());
      if (onComplete != null) onComplete();
      return;
    }

    // 停止之前的播放
    await stop();

    final targetMode = mode ?? SubscriptionMode.free;
    _isSpeaking = true;

    // 立即通知 UI：开始加载
    onEvent?.call(const TtsEvent.loading());

    try {
      if (targetMode == SubscriptionMode.premium) {
        // 收费模式：使用 PCM 流式播放（低延迟）
        await _speakPremium(text: text, onEvent: onEvent, onComplete: onComplete);
      } else {
        // 免费模式：使用原生 TTS（文件播放或直接播放）
        await _speakFree(text: text, onEvent: onEvent, onComplete: onComplete, onProgress: onProgress);
      }
    } catch (e) {
      _ttsLog('🔊 [TtsPlayer] 💥 异常: $e');
      onEvent?.call(TtsEvent.error('TTS 错误: $e'));
      _isSpeaking = false;
      onEvent?.call(const TtsEvent.completed());
      if (onComplete != null) onComplete();
    }
  }

  /// 收费模式：使用 DashScope PCM 流式播放
  Future<void> _speakPremium({
    required String text,
    void Function(TtsEvent)? onEvent,
    FutureOr<void> Function()? onComplete,
  }) async {
    _ttsLog('🔊 [TtsPlayer] 🎵 使用 PCM 流式播放: "$text"');

    // 通知 UI：开始播放
    onEvent?.call(const TtsEvent.playing());

    final completer = Completer<void>();

    await DashScopeTtsService.instance.streamSynthesizeAndPlay(
      text: text,
      onComplete: () {
        _ttsLog('🔊 [TtsPlayer] ✅ PCM 流式播放完成');
        _isSpeaking = false;
        onEvent?.call(const TtsEvent.completed());
        if (onComplete != null) onComplete();
        if (!completer.isCompleted) completer.complete();
      },
      onError: (error) {
        _ttsLog('🔊 [TtsPlayer] ❌ PCM 流式播放错误: $error');
        _isSpeaking = false;
        onEvent?.call(TtsEvent.error('TTS 播放错误: $error'));
        onEvent?.call(const TtsEvent.completed());
        if (onComplete != null) onComplete();
        if (!completer.isCompleted) completer.complete();
      },
    );

    // 等待播放完成或错误
    await completer.future;
  }

  /// 免费模式：使用原生 TTS（文件播放或直接播放）
  Future<void> _speakFree({
    required String text,
    void Function(TtsEvent)? onEvent,
    FutureOr<void> Function()? onComplete,
    void Function(double fraction)? onProgress,
  }) async {
    final result = await UnifiedTtsService.instance.synthesize(
      text: text,
      mode: SubscriptionMode.free,
      onWord: null,
    );

    if (result.success) {
      // 检查是否为直接播放模式（audioPath 为空）
      if (result.audioPath.isEmpty || result.format == 'direct') {
        _ttsLog('🔊 [TtsPlayer] 📢 使用直接播放模式（跳过文件）');
        onEvent?.call(const TtsEvent.playing());
        // 直接播放已完成，因为 synthesizeToAudio 已经调用了 speak
        // 根据字数估算播放时长，使高亮定时器与播放保持同步
        // 基准：150 词/分钟 ≈ 400ms/词
        final wordCount =
            text.trim().isEmpty ? 1 : text.trim().split(RegExp(r'\s+')).length;
        final estimatedMs = (wordCount * 400).clamp(500, 30000);
        final sw = Stopwatch()..start();
        Timer? progressTimer;
        progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
          final fraction = sw.elapsedMilliseconds / estimatedMs;
          onProgress?.call(fraction.clamp(0.0, 1.0));
          if (fraction >= 1.0) {
            progressTimer?.cancel();
          }
        });
        await Future.delayed(Duration(milliseconds: estimatedMs));
        progressTimer.cancel();
        _ttsLog('🔊 [TtsPlayer] ✅ 直接播放完成');
        _isSpeaking = false;
        onEvent?.call(const TtsEvent.completed());
        if (onComplete != null) onComplete();
        return;
      }

      // 检查文件是否存在且有效
      final file = io.File(result.audioPath);
      if (!await file.exists()) {
        _ttsLog('🔊 [TtsPlayer] ❌ 音频文件不存在: ${result.audioPath}');
        onEvent?.call(TtsEvent.error('音频文件不存在'));
        _isSpeaking = false;
        if (onComplete != null) onComplete();
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _ttsLog('🔊 [TtsPlayer] ❌ 音频文件为空: ${result.audioPath}');
        onEvent?.call(TtsEvent.error('音频文件为空'));
        _isSpeaking = false;
        if (onComplete != null) onComplete();
        return;
      }

      _ttsLog('🔊 [TtsPlayer] 📁 音频文件就绪: ${fileSize} bytes | ${result.audioPath.split('/').last}');

      // 通知 UI：开始播放
      onEvent?.call(const TtsEvent.playing());

      // 复用同一个 AudioPlayer 实例，避免 flutter_pcm_player 索引越界
      try {
        // 先停止当前播放
        if (_player.state == ap.PlayerState.playing) {
          await _player.stop();
        }
        
        final playSw = Stopwatch()..start();
        await _player.play(ap.DeviceFileSource(result.audioPath));
        playSw.stop();

        _ttsLog('🔊 [TtsPlayer] ▶️ 开始播放 (${playSw.elapsedMilliseconds}ms) | fromCache=${result.fromCache} | path=${result.audioPath.split('/').last}');

        // 用播放进度驱动高亮
        StreamSubscription? posSub;
        final duration = await _player.getDuration();
        if (duration != null && duration.inMilliseconds > 0) {
          posSub = _player.onPositionChanged.listen((pos) {
            final fraction = pos.inMilliseconds / duration.inMilliseconds;
            onProgress?.call(fraction.clamp(0.0, 1.0));
          });
        }

        await _player.onPlayerComplete.first;

        await posSub?.cancel();
        _ttsLog('🔊 [TtsPlayer] ✅ 播放完成');
      } catch (e) {
        _ttsLog('🔊 [TtsPlayer] ❌ 播放异常: $e');
      }

      _isSpeaking = false;
      onEvent?.call(const TtsEvent.completed());
      if (onComplete != null) onComplete();
    } else {
      // 合成失败
      _ttsLog('🔊 [TtsPlayer] ❌ 合成失败: ${result.error}');
      onEvent?.call(TtsEvent.error(result.error ?? 'TTS 合成失败'));
      _isSpeaking = false;
      onEvent?.call(const TtsEvent.completed());
      if (onComplete != null) onComplete();
    }
  }

  /// 朗读单词（慢速、清晰）
  Future<void> speakWord(
    String word, {
    SubscriptionMode? mode,
    FutureOr<void> Function()? onComplete,
    void Function(TtsEvent)? onEvent,
  }) async {
    await speakClarity(text: word, mode: mode, onComplete: onComplete, onEvent: onEvent);
  }

  /// 朗读字幕（适用于视频播放器中逐句朗读）
  Future<void> speakSubtitle(
    String text, {
    SubscriptionMode? mode,
    FutureOr<void> Function()? onComplete,
    void Function(TtsEvent)? onEvent,
  }) async {
    await speakClarity(text: text, mode: mode, onComplete: onComplete, onEvent: onEvent);
  }

  /// 预加载 TTS（不阻塞，用于提前合成下一句）
  Future<void> prefetch({
    required String text,
    required SubscriptionMode mode,
  }) async {
    await UnifiedTtsService.instance.prefetch(text: text, mode: mode);
  }

  /// 批量预加载多个文本
  Future<void> prefetchBatch({
    required List<String> texts,
    required SubscriptionMode mode,
  }) async {
    await UnifiedTtsService.instance.prefetchBatch(texts: texts, mode: mode);
  }

  /// 清除所有 TTS 缓存（包括磁盘文件）
  Future<void> clearCache() async {
    await UnifiedTtsService.instance.clearCache();
  }

  /// 获取 TTS 缓存统计（条数 + 总大小）
  Future<TtsCacheStats> getCacheStats() async {
    return UnifiedTtsService.instance.getCacheStats();
  }

  /// 停止朗读
  Future<void> stop() async {
    _isSpeaking = false;
    // 停止 AudioPlayer 播放（文件模式）
    if (_player.state == ap.PlayerState.playing) {
      await _player.stop();
    }
    // 停止 PCM 流式播放（收费模式）
    await DashScopeTtsService.instance.stopPcmPlayback();
    // 停止本地 TTS（免费模式，flutter_tts → AVSpeechSynthesizer）
    await LocalTtsService.instance.stop();
  }

  void _ttsLog(String message) {
    if (kReleaseMode) {
      // ignore: avoid_print
      print(message);
    } else {
      debugPrint(message);
    }
  }
}
