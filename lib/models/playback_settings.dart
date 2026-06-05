import 'package:vidlang/models/video_folder.dart';

/// 播放相关设置（片头/片尾跳过、封面截图时间）
class PlaybackSettings {
  final bool skipOpening;
  final int skipOpeningDuration;
  final bool skipEnding;
  final int skipEndingDuration;
  final int thumbnailTime;

  const PlaybackSettings({
    this.skipOpening = false,
    this.skipOpeningDuration = 0,
    this.skipEnding = false,
    this.skipEndingDuration = 0,
    this.thumbnailTime = 15,
  });

  factory PlaybackSettings.fromFolder(VideoFolder folder) {
    return PlaybackSettings(
      skipOpening: folder.skipOpening,
      skipOpeningDuration: folder.skipOpeningDuration,
      skipEnding: folder.skipEnding,
      skipEndingDuration: folder.skipEndingDuration,
      thumbnailTime: folder.thumbnailTime,
    );
  }

  PlaybackSettings copyWith({
    bool? skipOpening,
    int? skipOpeningDuration,
    bool? skipEnding,
    int? skipEndingDuration,
    int? thumbnailTime,
  }) {
    return PlaybackSettings(
      skipOpening: skipOpening ?? this.skipOpening,
      skipOpeningDuration: skipOpeningDuration ?? this.skipOpeningDuration,
      skipEnding: skipEnding ?? this.skipEnding,
      skipEndingDuration: skipEndingDuration ?? this.skipEndingDuration,
      thumbnailTime: thumbnailTime ?? this.thumbnailTime,
    );
  }

  /// 有效播放起点（毫秒）
  int effectiveStartMs() =>
      skipOpening ? skipOpeningDuration * 1000 : 0;

  /// 有效播放终点（毫秒），[durationMs] 为视频总时长
  int effectiveEndMs(int durationMs) {
    if (durationMs <= 0) return 0;
    final endingSkip = skipEnding ? skipEndingDuration * 1000 : 0;
    final end = durationMs - endingSkip;
    final start = effectiveStartMs();
    return end > start ? end : durationMs;
  }

  /// 是否视为播完
  bool isPlaybackCompleted(int currentPositionMs, int durationMs) {
    if (durationMs <= 0) return false;
    return currentPositionMs >= effectiveEndMs(durationMs) - 500;
  }
}
