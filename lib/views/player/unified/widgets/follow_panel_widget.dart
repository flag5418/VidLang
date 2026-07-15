import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/views/player/unified/providers/player_engine_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/utils/app_globals.dart';
import 'package:vidlang/widgets/shadow_reader/shadow_reader_component.dart';

/// 跟读/跟唱面板组件
///
/// 对 ShadowReaderComponent.inline() 的标准化封装，
/// 统一处理视频和音频两种模式的配置差异。
class FollowPanelWidget extends ConsumerWidget {
  final String audioType;
  final String videoCode;
  final String title;
  final String language;
  final PlayerEngineState state;
  final PlayerEngineNotifier notifier;
  final Subtitles currentSub;
  final VoidCallback onClose;

  const FollowPanelWidget({
    super.key,
    required this.audioType,
    required this.videoCode,
    required this.title,
    required this.language,
    required this.state,
    required this.notifier,
    required this.currentSub,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final isPad = AppGlobals.isTablet;

    // 根据资源类型确定高度比例
    double heightFactor;
    if (audioType == 'video') {
      heightFactor = isLandscape ? (isPad ? 0.5 : 0.6) : 0.55;
    } else {
      heightFactor = 0.45;
    }

    return ShadowReaderComponent.inline(
      config: ShadowReaderConfig(
        subtitle: currentSub,
        resourceType: audioType,
        resourceCode: videoCode,
        resourceTitle: title,
        language: language,
        isMusic: audioType == 'music',
        scope: 'sentence',
        getPosition: () => state.position,
        seekTo: (d) async => notifier.seekToMs(d.inMilliseconds),
        togglePlayPause: () async => notifier.togglePlayPause(),
        pause: () async => notifier.player.pause(),
        play: () async => notifier.player.play(),
        setOriginalVolume: (v) async => notifier.setOriginalVolume(v),
        setSpeed: (v) async => notifier.setSpeed(v),
        currentSpeed: state.speed,
        getSingleSentencePause: state.singleSentencePause,
        setSingleSentencePause: (v) async => notifier.setSingleSentencePause(v),
        setRecording: (v) async => notifier.setRecording(v),
        setLastFollowScore: (v) async => notifier.setLastFollowScore(v),
        getCurrentVideo: () => notifier.currentVideo,
        speakSubtitle: (text) async {
          final subState = ref.read(subscriptionProvider);
          await TtsService().speakSubtitle(text, mode: subState.mode);
        },
        isTtsSpeaking: null, // 由外部管理
        currentSubtitleIndex: state.currentSubtitleIndex,
        nextSentence: () async => notifier.nextSentence(),
        previousSentence: () async => notifier.previousSentence(),
        playAtSubtitleIndex: (index) async {
          if (index < 0 || index >= notifier.subtitles.length) return;
          final sub = notifier.subtitles[index];
          await notifier.seekToMs(Duration(milliseconds: sub.startPosition.toInt()).inMilliseconds);
          await notifier.player.play();
        },
      ),
      heightFactor: heightFactor,
      onClose: onClose,
    );
  }
}
