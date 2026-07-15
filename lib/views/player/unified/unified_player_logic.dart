import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omni_player/omni_player.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/views/player/unified/providers/player_engine_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/evaluation/audio_recognition_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/utils/initial_letter_cover.dart';
import 'package:vidlang/services/files/thumbnail_service.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/services/ai/translation_init_service.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/services/evaluation/unified_evaluation_service.dart';
import 'package:record/record.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/views/player/unified/widgets/score_result_dialog.dart';

/// 统一播放器的业务逻辑层
///
/// 从主页面 State 中提取的纯逻辑方法，
/// 通过构造函数接收 context/ref 等依赖，避免直接操作 Widget。
class UnifiedPlayerLogic {
  final dynamic ref;
  final bool Function() mounted;
  final void Function(void Function()) setState;
  final BuildContext Function() context;

  // 外部传入的参数（避免循环依赖）
  final String videoCode;
  final String? audioType;
  final List<VideoInfo>? folderVideos;

  bool get isVideo => audioType == null || audioType == 'video';

  UnifiedPlayerLogic({
    required this.ref,
    required this.mounted,
    required this.setState,
    required this.context,
    required this.videoCode,
    this.audioType,
    this.folderVideos,
  });

  // ─── 生命周期管理 ────────────────────────────────

  /// 锁定方向（横竖屏可转）
  void lockOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// 解除方向锁定（恢复默认）
  void unlockOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// App 进入后台时暂停播放
  void handleAppLifecyclePaused() {
    final notifier = ref.read(playerEngineProvider.notifier);
    if (ref.read(playerEngineProvider).playerState == PlayerState.playing) {
      notifier.togglePlayPause();
    }
  }

  /// 清理资源
  void dispose() {}

  // ─── 初始化相关 ─────────────────────────────────

  /// 加载文件夹下的视频/音频列表
  Future<List<VideoInfo>?> loadFolderVideos(String code) async {
    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'code = ? AND is_deleted = 0',
      whereArgs: [code],
    );
    if (videos.isEmpty) return null;
    final fc = videos.first.folderCode;
    if (fc.isEmpty) return null;
    return await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [fc],
      orderBy: 'created_at ASC',
    );
  }

  /// 检查并初始化翻译
  Future<void> checkAndInitializeTranslation({
    required PlayerEngineNotifier notifier,
    required void Function(bool inProgress) onProgress,
  }) async {
    final subtitles = notifier.subtitles;
    if (subtitles.isEmpty) return;

    final subState = ref.read(subscriptionProvider);
    final needCount = TranslationInitService.countNeedTranslate(
      subtitles,
      subState.mode,
    );
    if (needCount == 0) return;

    onProgress(true);
    // 使用 addPostFrameCallback 确保 Overlay 已就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted()) {
        TDToast.showText('正在进行翻译初始化...', context: context());
      }
    });

    final currentTitle = notifier.currentVideo?.name ?? videoCode;

    try {
      await TranslationInitService.translateSubtitles(
        subtitles: subtitles,
        videoCode: videoCode,
        title: currentTitle,
        mode: subState.mode,
        onProgress: (current, total) {},
      );
      if (mounted()) setState(() {});
    } catch (e) {
      debugPrint('Translation init failed: $e');
      if (mounted()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted()) {
            TDToast.showFail('翻译初始化失败', context: context());
          }
        });
      }
    } finally {
      onProgress(false);
    }
  }

  // ─── 封面解析 ───────────────────────────────────

  /// 解析音频封面（ID3 → InitialLetterCover → DB）
  Future<void> resolveCover({
    required void Function(String? path) onResolved,
  }) async {
    final video = ref.read(playerEngineProvider.notifier).currentVideo;
    if (video == null) return;

    String? coverFile;
    if (video.currentCover != null && video.currentCover!.isNotEmpty) {
      coverFile = video.currentCover;
    } else if (video.cover != null && video.cover!.isNotEmpty) {
      coverFile = video.cover;
    }

    if (coverFile != null && coverFile.isNotEmpty) {
      final fullPath = await ThumbnailService.getFullPath(coverFile);
      if (File(fullPath).existsSync()) {
        onResolved(fullPath);
        return;
      }
    }

    // Try ID3 tags
    if (video.artist == null && video.album == null) {
      try {
        final id3Tags = await AudioRecognitionService.extractId3Tags(
          video.filePath,
        );
        if (id3Tags != null) {
          if (id3Tags.artist != null) video.artist = id3Tags.artist;
          if (id3Tags.album != null) video.album = id3Tags.album;
          if (id3Tags.title != null && video.name.isEmpty) {
            video.name = id3Tags.title!;
          }
          if (id3Tags.coverData != null) {
            final coverCode = '${DateTime.now().millisecondsSinceEpoch}';
            final coverPath = 'covers/${video.folderCode}/$coverCode.jpg';
            final fullPath = await ThumbnailService.getFullPath(coverPath);
            final dir = Directory(fullPath).parent;
            if (!await dir.exists()) await dir.create(recursive: true);
            await File(fullPath).writeAsBytes(id3Tags.coverData!);
            video.cover = coverPath;
            video.coverSource = 'id3';
            coverFile = coverPath;
          }
          await DatabaseService.update(video);
        }
      } catch (_) {}
    }

    // Generate initial letter cover
    if (coverFile == null || coverFile.isEmpty) {
      final generated = await InitialLetterCover.generate(
        video.name,
        video.folderCode,
      );
      if (generated != null) {
        video.cover = generated;
        video.coverSource = 'initial_letter';
        await DatabaseService.update(video);
        coverFile = generated;
      }
    }

    if (coverFile != null && coverFile.isNotEmpty) {
      final fullPath = await ThumbnailService.getFullPath(coverFile);
      if (File(fullPath).existsSync()) {
        onResolved(fullPath);
      }
    }
  }

  // ─── TTS 清晰朗读 ──────────────────────────────

  /// 处理清晰朗读
  void handleClaritySpeak({
    required PlayerEngineNotifier notifier,
    required PlayerEngineState state,
    required Subtitles sub,
    required void Function(bool speaking) onSpeakingChanged,
  }) async {
    final wasPlaying = state.playerState == PlayerState.playing;
    if (wasPlaying) notifier.player.pause();

    onSpeakingChanged(true);

    final subState = ref.read(subscriptionProvider);
    await TtsService().speakClarity(
      text: sub.content,
      mode: subState.mode,
      onComplete: () {
        if (!mounted()) return;
        onSpeakingChanged(false);
        if (wasPlaying && !ref.read(playerEngineProvider).singleSentencePause) {
          notifier.player.play();
        }
      },
    );
  }

  /// 停止清晰朗读
  void stopClaritySpeak() {
    TtsService().stop();
  }

  /// 朗读选中的单词
  Future<void> speakSelectedWord(String word) async {
    final subState = ref.read(subscriptionProvider);
    try {
      await TtsService().speakClarity(
        text: word,
        mode: subState.mode,
        onComplete: () {},
      );
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  // ─── 单词保存 ──────────────────────────────────

  /// 保存单词到生词本
  Future<bool> handleSaveWord({
    required String word,
    String? contextSentence,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
  }) async {
    final notifier = ref.read(playerEngineProvider.notifier);
    final state = ref.read(playerEngineProvider);
    final video = notifier.currentVideo;
    final subtitlesList = notifier.subtitles;
    final idx = state.currentSubtitleIndex;
    final currentSub = (idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;

    final result = await WordBookService.saveWord(
      word: word,
      sourceType: sourceType,
      sourceCode: sourceCode,
      sourceTitle: sourceTitle,
      contextSentence: contextSentence,
      segmentCode: currentSub?.code,
      videoPath: video?.filePath,
      positionMs: state.position.inMilliseconds,
    );
    return result != null;
  }

  // ─── 录音评分（RecordingSession）─────────────────

  /// 开始跟读录音
  Future<void> startFollowRecording({
    required AudioRecorder recorder,
    required String? Function() recordingPathGetter,
    required void Function(String?) recordingPathSetter,
    required DateTime? Function() startTimeGetter,
    required void Function(DateTime?) startTimeSetter,
    required Timer? Function() autoStopTimerGetter,
    required void Function(Timer?) autoStopTimerSetter,
    required Subtitles currentSub,
    required PlayerEngineState state,
    required PlayerEngineNotifier notifier,
    required BuildContext ctx,
  }) async {
    if (!await recorder.hasPermission()) {
      if (mounted() && ctx.mounted) {
        TDToast.showText('需要麦克风权限才能跟读', context: ctx);
      }
      return;
    }

    notifier.setRecording(true);
    startTimeSetter(DateTime.now());

    try {
      final tmpDir = Directory.systemTemp;
      final path =
          '${tmpDir.path}/follow_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(const RecordConfig(), path: path);
      recordingPathSetter(path);

      // Save original volume, lower to follow volume
      final defaultVol = isVideo ? 0.6 : 0.8;
      await notifier.setOriginalVolume(defaultVol);

      if (!state.singleSentencePause) notifier.setSingleSentencePause(true);
      if (state.playerState != PlayerState.playing) {
        notifier.seekToMs(currentSub.startPosition.toInt());
        notifier.togglePlayPause();
      }

      // Auto-stop timer
      autoStopTimerGetter()?.cancel();
      final endMs = currentSub.endPosition.toInt();
      final bufferMs = isVideo ? 500 : 1000;
      final remainingMs = endMs - state.position.inMilliseconds;
      if (remainingMs > 0) {
        autoStopTimerSetter(
          Timer(Duration(milliseconds: remainingMs + bufferMs), () {
            if (mounted() && ref.read(playerEngineProvider).isRecording) {
              stopFollowRecording(
                recorder: recorder,
                recordingPath: recordingPathGetter(),
                autoStopTimer: autoStopTimerGetter(),
                autoStopTimerSetter: autoStopTimerSetter,
                startTime: startTimeGetter(),
                currentSub: currentSub,
                state: ref.read(playerEngineProvider),
                notifier: ref.read(playerEngineProvider.notifier),
                ctx: ctx,
              );
            }
          }),
        );
      }
    } catch (_) {
      notifier.setRecording(false);
      if (mounted()) {
        TDToast.showText('录音启动失败', context: ctx);
      }
    }
  }

  /// 停止跟读录音并触发评测
  Future<void> stopFollowRecording({
    required AudioRecorder recorder,
    required String? recordingPath,
    required Timer? autoStopTimer,
    required void Function(Timer?) autoStopTimerSetter,
    required DateTime? startTime,
    required Subtitles currentSub,
    required PlayerEngineState state,
    required PlayerEngineNotifier notifier,
    required BuildContext ctx,
  }) async {
    autoStopTimer?.cancel();
    autoStopTimerSetter(null);
    if (recordingPath == null) return;

    try {
      await recorder.stop();
    } catch (_) {}
    notifier.setRecording(false);

    // Restore volume to 100%
    await notifier.setOriginalVolume(1.0);

    final path = recordingPath;
    if (!File(path).existsSync()) return;

    _evaluateRecording(
      audioPath: path,
      startTime: startTime,
      currentSub: currentSub,
      state: state,
      notifier: notifier,
      ctx: ctx,
    );
  }

  /// 评测录音
  Future<void> _evaluateRecording({
    required String audioPath,
    required DateTime? startTime,
    required Subtitles currentSub,
    required PlayerEngineState state,
    required PlayerEngineNotifier notifier,
    required BuildContext ctx,
  }) async {
    final video = notifier.currentVideo;
    final language = video?.language ?? 'en';

    // 使用统一评测服务（当前 Premium 模式返回待实现状态）
    final evalResult = await UnifiedEvaluationService.instance.evaluate(
      refText: currentSub.content,
      mode: SubscriptionMode.premium, // TODO: 根据实际订阅模式传入
      audioPath: audioPath,
    );

    if (evalResult.success && mounted()) {
      final overall = evalResult.overallScore;
      final detail = evalResult.detail;

      final recordingDurationMs = startTime != null
          ? DateTime.now().difference(startTime).inMilliseconds
          : 0;

      final record = RecordingRecord(
        resourceCode: videoCode,
        resourceType: isVideo ? 'video' : (audioType ?? 'music'),
        scope: 'sentence',
        sentenceCode: currentSub.code,
        audioPath: audioPath,
        durationMs: recordingDurationMs,
        overallScore: overall > 0 ? overall : null,
        fluencyScore: detail?.fluency,
        accuracyScore: detail?.accuracy,
        completenessScore: detail?.completeness,
        rawResultJson: evalResult.detail?.rawResult?.toString(),
        language: language,
        refText: currentSub.content,
        subtitleIndex: state.currentSubtitleIndex,
        originalVolume: state.originalVolume,
        speed: state.speed,
        headphoneMode: false, // TODO: 耳机检测
      );
      await DatabaseService.insert(record);

      if (overall > 0) {
        notifier.setLastFollowScore(overall);
        if (video != null) {
          video.lastFollowScore = overall;
          await DatabaseService.update(video);
        }
      }

      // 显示评分结果
      ScoreResultDialog.show(
        ctx,
        overall: overall > 0 ? overall : null,
        fluency: detail?.fluency,
        accuracy: detail?.accuracy,
        completeness: detail?.completeness,
        onNext: () => notifier.nextSentence(),
      );
    } else if (mounted()) {
      TDToast.showText(evalResult.error ?? '评分服务暂时不可用', context: ctx);
    }
  }

  // ─── 工具方法 ──────────────────────────────────

  /// 时长格式化
  static String fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 分数颜色映射
  static Color scoreColor(double score) {
    if (score >= 90) return const Color(0xFF4CAF50); // success
    if (score >= 75) return const Color(0xFFFFC107); // warning
    if (score >= 60) return const Color(0xFFF44336); // error
    return const Color(0xFFF44336); // error
  }
}
