import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:record/record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/widgets/word_card.dart';

import 'unified_player_logic.dart';
import 'widgets/media_area.dart';
import 'widgets/top_bar.dart';
import 'widgets/bottom_controls.dart';
import 'widgets/side_drawer.dart';
import 'widgets/follow_panel_widget.dart';

/// 统一播放器页面
///
/// 通过 [audioType] 区分资源类型：
/// - `null` 或 `'video'` → 视频模式（VideoWidget + 可选字幕）
/// - `'music'` 或 `'podcast'` 等 → 音频模式（模糊封面 + 字幕列表）
class UnifiedPlayerPage extends ConsumerStatefulWidget {
  final String videoCode;
  final List<VideoInfo>? folderVideos;
  final String? audioType;

  const UnifiedPlayerPage({
    super.key,
    required this.videoCode,
    this.folderVideos,
    this.audioType,
  });

  /// 是否为视频模式
  bool get isVideo => audioType == null || audioType == 'video';

  @override
  ConsumerState<UnifiedPlayerPage> createState() => _UnifiedPlayerPageState();
}

class _UnifiedPlayerPageState extends ConsumerState<UnifiedPlayerPage>
    with WidgetsBindingObserver {
  // ─── UI 状态（setState 管理）──────────────────────────

  /// 是否显示侧边栏
  bool _showDrawer = false;

  /// 设置面板是否展开（竖屏 BottomControls）
  bool _settingsExpanded = false;

  /// 是否显示跟读/跟唱面板
  bool _showFollow = false;

  /// TTS 清晰朗读中
  bool _isTtsSpeaking = false;

  /// 解析后的封面路径（音频模式）
  String? _resolvedCoverPath;

  /// 文件夹视频列表（覆盖 state 中的）
  List<VideoInfo>? _folderVideosOverride;

  /// 初始化完成标记
  bool _initialized = false;

  /// 翻译进行中
  bool _translationInProgress = false;

  // 录音相关状态
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  Timer? _autoStopTimer;
  DateTime? _recordingStartTime;

  // ─── 逻辑助手 ──────────────────────────────────────

  late final UnifiedPlayerLogic _logic;

  // ─── 生命周期 ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSystemUI();
    // 延迟到第一帧后再初始化 logic 和播放器，确保 Overlay 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logic = UnifiedPlayerLogic(
        ref: ref,
        mounted: () => mounted,
        setState: (fn) { if (mounted) setState(fn); },
        context: () => context,
        videoCode: widget.videoCode,
        audioType: widget.audioType,
        folderVideos: widget.folderVideos,
      );
      _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoStopTimer?.cancel();
    _recorder.dispose();
    _logic.dispose();
    _restoreSystemUI(); // 恢复系统 UI
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _logic.handleAppLifecyclePaused();
    }
  }

  // ─── 初始化 ────────────────────────────────────────

  void _setupSystemUI() {
    // 允许所有方向旋转
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 沉浸式：隐藏状态栏和导航栏
    // edge-to-edge 模式，用户从屏幕边缘滑动可临时恢复
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // 设置状态栏/导航栏样式（透明 + 浅色图标）
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  /// 页面退出时恢复系统 UI
  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    final notifier = ref.read(playerEngineProvider.notifier);

    // 打开资源
    if (widget.isVideo) {
      await notifier.openVideoByCode(widget.videoCode);
    } else {
      await notifier.openAudioByCode(widget.videoCode, widget.audioType!);
    }

    await notifier.reloadSubtitles(widget.videoCode);

    // 加载文件夹列表
    if (widget.folderVideos != null) {
      _folderVideosOverride = widget.folderVideos;
    } else {
      final list = await _logic.loadFolderVideos(widget.videoCode);
      if (mounted) _folderVideosOverride = list;
    }

    // 解析封面（音频模式）
    if (!widget.isVideo) {
      await _logic.resolveCover(onResolved: (path) {
        if (mounted) _resolvedCoverPath = path;
      });
    }

    // 翻译初始化
    if (mounted) {
      await _logic.checkAndInitializeTranslation(
        notifier: notifier,
        onProgress: (inProgress) {
          if (mounted) _translationInProgress = inProgress;
        },
      );
    }
  }

  // ─── 构建 ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerEngineProvider);
    final notifier = ref.read(playerEngineProvider.notifier);
    final subtitlesList = notifier.subtitles;
    final hasSubtitles = subtitlesList.isNotEmpty;
    final idx = state.currentSubtitleIndex;
    final currentSub = (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;
    final colors = context.colors;
    final isPad = adaptive.Adaptive.of(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // iPad 横屏：70/30 分栏布局
    if (isPad && isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            Expanded(
              flex: 7,
              child: _buildPlayerStack(
                state: state,
                notifier: notifier,
                subtitlesList: subtitlesList,
                hasSubtitles: hasSubtitles,
                currentSub: currentSub,
                colors: colors,
                showDrawerPermanent: true,
                isLandscape: isLandscape,
              ),
            ),
            Expanded(
              flex: 3,
              child: SideDrawer(
                isOpen: true,
                isPermanent: true,
                videos: _getVideoList(state),
                currentVideoCode: state.videoCode ?? '',
                title: widget.isVideo ? '推荐视频' : '音频列表',
                onSwitchTo: (code) { _switchResource(code, notifier); },
                onClose: () {},
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: widget.isVideo ? Colors.black : colors.background,
      body: _buildPlayerStack(
        state: state,
        notifier: notifier,
        subtitlesList: subtitlesList,
        hasSubtitles: hasSubtitles,
        currentSub: currentSub,
        colors: colors,
        showDrawerPermanent: false,
        isLandscape: isLandscape,
      ),
    );
  }

  /// 构建播放器主 Stack
  Widget _buildPlayerStack({
    required PlayerEngineState state,
    required PlayerEngineNotifier notifier,
    required List<Subtitles> subtitlesList,
    required bool hasSubtitles,
    required Subtitles? currentSub,
    required AppColorsData colors,
    required bool showDrawerPermanent,
    required bool isLandscape,
  }) {
    return Stack(
      children: [
        MediaArea(
          isVideo: widget.isVideo,
          isLandscape: isLandscape,
          player: notifier.player,
          coverPath: _resolvedCoverPath,
          videoCode: widget.videoCode,
          subtitlesList: subtitlesList,
          currentIndex: state.currentSubtitleIndex,
          subtitleVisible: state.subtitleVisible,
          translateVisible: state.translateVisible,
          pronunciationVisible: state.pronunciationVisible,
          fontSize: state.subtitleFontSize,
          onTapSubtitle: (i) => notifier.jumpToSubtitle(i),
          onWordSelected: (words, sub) => _handleWordSelected(words, sub, state, notifier),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TopBar(
            title: state.title,
            isLandscape: isLandscape,
            onBack: () {
              _restoreSystemUI();
              Navigator.pop(context);
            },
            onToggleDrawer: () {
              if (!showDrawerPermanent) setState(() => _showDrawer = !_showDrawer);
            },
            isDrawerOpen: _showDrawer,
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BottomControls(
            isVideo: widget.isVideo,
            isLandscape: isLandscape,
            state: state,
            notifier: notifier,
            hasSubtitles: hasSubtitles,
            currentSub: currentSub,
            showFollow: _showFollow,
            isTtsSpeaking: _isTtsSpeaking,
            settingsExpanded: _settingsExpanded,
            onToggleFollow: () => _handleToggleFollow(notifier, state, currentSub),
            onClaritySpeak: (currentSub != null)
                ? () => _handleClaritySpeak(notifier, state, currentSub!)
                : null,
            onStopSpeak: () => _handleStopSpeak(),
            onToggleSettings: () => setState(() => _settingsExpanded = !_settingsExpanded),
            onWordSelected: (words, sub) => _handleWordSelected(words, sub, state, notifier),
            onToggleFullscreen: _toggleFullscreen,
          ),
        ),

        if (_showFollow && currentSub != null && !_showFollowPanelBlocked)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FollowPanelWidget(
              audioType: widget.audioType ?? 'video',
              videoCode: widget.videoCode,
              title: state.title,
              language: notifier.currentVideo?.language ?? 'en',
              state: state,
              notifier: notifier,
              currentSub: currentSub!,
              onClose: () {
                setState(() => _showFollow = false);
                notifier.exitFollowMode();
              },
            ),
          ),

        if (_showDrawer && !showDrawerPermanent)
          SideDrawer(
            isOpen: _showDrawer,
            isPermanent: false,
            videos: _getVideoList(state),
            currentVideoCode: state.videoCode ?? '',
            title: widget.isVideo ? '视频列表' : '音频列表',
            onSwitchTo: (code) {
              setState(() => _showDrawer = false);
              _switchResource(code, notifier);
            },
            onClose: () => setState(() => _showDrawer = false),
          ),
      ],
    );
  }

  // ─── 回调处理 ─────────────────────────────────────

  bool get _showFollowPanelBlocked => _showDrawer;

  void _toggleFullscreen() {
    final isCurrentlyLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isCurrentlyLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  List<VideoInfo> _getVideoList(PlayerEngineState state) {
    return state.folderVideos.isNotEmpty
        ? state.folderVideos
        : (_folderVideosOverride ?? const <VideoInfo>[]);
  }

  void _switchResource(String code, PlayerEngineNotifier notifier) async {
    if (widget.isVideo) {
      await notifier.switchToVideo(code);
    } else {
      await notifier.switchToAudio(code, widget.audioType!);
      await _logic.resolveCover(onResolved: (path) {
        if (mounted) _resolvedCoverPath = path;
      });
    }
    if (mounted) setState(() {});
  }

  void _handleToggleFollow(PlayerEngineNotifier n, PlayerEngineState s, Subtitles? cs) {
    if (_showFollow) {
      setState(() => _showFollow = false);
      n.exitFollowMode();
    } else {
      if (_translationInProgress) return;
      setState(() => _showFollow = true);
      n.enterFollowMode();
      n.setSingleSentencePause(true);
      if (cs != null) {
        n.seekToMs(cs.startPosition.toInt());
        Future.microtask(() => n.player.play());
      }
    }
  }

  void _handleClaritySpeak(PlayerEngineNotifier n, PlayerEngineState s, Subtitles cs) {
    _logic.handleClaritySpeak(
      notifier: n,
      state: s,
      sub: cs,
      onSpeakingChanged: (speaking) {
        if (mounted) setState(() => _isTtsSpeaking = speaking);
      },
    );
  }

  void _handleStopSpeak() {
    _logic.stopClaritySpeak();
    if (mounted) setState(() => _isTtsSpeaking = false);
  }

  void _handleWordSelected(List<String> words, Subtitles sub, PlayerEngineState s, PlayerEngineNotifier n) async {
    if (words.isEmpty) return;
    final selectedText = words.join(' ');
    final wasPlaying = s.playerState == PlayerState.playing;
    n.player.pause();

    WordCard.show(
      context,
      word: selectedText,
      contextSentence: sub.content,
      onSpeak: () => _logic.speakSelectedWord(selectedText),
      onSaveWord: ({required String word, String? contextSentence, required String sourceType, required String sourceCode, String? sourceTitle}) async {
        final result = await _logic.handleSaveWord(
          word: word,
          contextSentence: contextSentence,
          sourceType: sourceType,
          sourceCode: sourceCode,
          sourceTitle: sourceTitle ?? s.title,
        );
        return result;
      },
      sourceType: widget.isVideo ? 'video' : (widget.audioType ?? 'music'),
      sourceCode: widget.videoCode,
      sourceTitle: s.title,
      segmentCode: sub.code,
    ).then((_) {
      if (wasPlaying && mounted) n.player.play();
    });
  }
}
