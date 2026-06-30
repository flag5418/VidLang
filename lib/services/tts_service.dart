import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:vidlang/providers/subscription_provider.dart';
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
/// - 收费模式 → 阿里云 TTS（Edge Function，带持久化磁盘缓存优化）
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
  ap.AudioPlayer? _currentPlayer;

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
      final result = await UnifiedTtsService.instance.synthesize(text: text, mode: targetMode);

      if (result.success && result.audioPath.isNotEmpty) {
        // 通知 UI：开始播放
        onEvent?.call(const TtsEvent.playing());

        final player = ap.AudioPlayer();
        _currentPlayer = player;

        final playSw = Stopwatch()..start();
        await player.play(ap.DeviceFileSource(result.audioPath));
        playSw.stop();

        _ttsLog('🔊 [TtsPlayer] ▶️ 开始播放 (${playSw.elapsedMilliseconds}ms) | fromCache=${result.fromCache} | path=${result.audioPath.split('/').last}');

        await player.onPlayerComplete.first;

        // 播放完成，清理引用
        _currentPlayer?.dispose();
        _currentPlayer = null;
        _isSpeaking = false;

        // 注意：不再删除缓存文件！
        // 缓存已由 UnifiedTtsService 持久化到 Documents 目录，
        // 下次调用相同文本时直接从磁盘读取，实现秒开。

        // 通知 UI：播放完成
        onEvent?.call(const TtsEvent.completed());
        if (onComplete != null) onComplete();
        return;
      } else {
        // 合成失败
        _ttsLog('🔊 [TtsPlayer] ❌ 合成失败: ${result.error}');
        onEvent?.call(TtsEvent.error(result.error ?? 'TTS 合成失败'));
      }
    } catch (e) {
      _ttsLog('🔊 [TtsPlayer] 💥 异常: $e');
      onEvent?.call(TtsEvent.error('TTS 错误: $e'));
    }

    _currentPlayer = null;
    _isSpeaking = false;
    onEvent?.call(const TtsEvent.completed());
    if (onComplete != null) onComplete();
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
    await _currentPlayer?.stop();
    await _currentPlayer?.dispose();
    _currentPlayer = null;
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
