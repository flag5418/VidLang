import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/video_info.dart';

/// 单集播放状态（详情列表展示）
enum PlayStatus {
  notStarted,
  inProgress,
  current,
  completed,
}

class PlayStatusHelper {
  PlayStatusHelper._();

  static PlayStatus of(VideoInfo video, PlaybackSettings settings) {
    if (video.isCurrentPlaying) return PlayStatus.current;
    if (settings.isPlaybackCompleted(video.currentPosition, video.duration)) {
      return PlayStatus.completed;
    }
    if (video.currentPosition > 0 ||
        (video.playDate != null && video.playCount > 0)) {
      return PlayStatus.inProgress;
    }
    return PlayStatus.notStarted;
  }
}
