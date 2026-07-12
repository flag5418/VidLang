import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/services/translation_init_service.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';
import 'package:vidlang/widgets/shadow_reader/shadow_reader_component.dart';
import 'package:vidlang/widgets/word_card.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final String videoCode;
  final List<VideoInfo>? folderVideos;
  const PlayerPage({super.key, required this.videoCode, this.folderVideos});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {
  bool _initialized = false;
  bool _translationInProgress = false;
  bool _showVideoList = false;
  bool _showReadAloud = false;
  List<VideoInfo>? _folderVideosOverride;

  // 控件自动隐藏
  bool _controlsVisible = true;
  Timer? _hideTimer;

  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final List<Map<String, String>> _playModeOptions = [
    {'label': '单集循环', 'value': 'single_loop'},
    {'label': '列表循环', 'value': 'list_loop'},
    {'label': '单集播放', 'value': 'single_play'},
    {'label': '顺序播放', 'value': 'sequence_play'},
  ];

  final ap.AudioPlayer _aliAudioPlayer = ap.AudioPlayer();
  bool _isTtsSpeaking = false;
  bool _showWordPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockLandscape();
    _loadSettings();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    Future.microtask(() => _initializePlayer());
    _resetAutoHide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aliAudioPlayer.dispose();
    _hideTimer?.cancel();
    _unlockOrientation();
    _initialized = false;
    super.dispose();
  }

  void _resetAutoHide() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_showReadAloud && !_showVideoList && !_showWordPopup) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _resetAutoHide();
  }

  void _lockLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  List<DeviceOrientation> _defaultOrientations() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
    if (shortestSide >= 600) {
      return [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }
    return [DeviceOrientation.portraitUp];
  }

  void _unlockOrientation() {
    SystemChrome.setPreferredOrientations(_defaultOrientations());
  }

  Future<void> _loadSettings() async {
    if (mounted) setState(() {});
  }

  Future<void> _initializePlayer() async {
    if (_initialized) return;
    _initialized = true;
    final notifier = ref.read(playerEngineProvider.notifier);
    await notifier.openVideoByCode(widget.videoCode);
    await notifier.reloadSubtitles(widget.videoCode);
    if (widget.folderVideos != null) {
      if (mounted) setState(() => _folderVideosOverride = widget.folderVideos);
    } else {
      await _loadFolderVideos();
    }
    if (mounted) {
      await _checkAndInitializeTranslation(notifier);
    }
  }

  Future<void> _loadFolderVideos() async {
    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
    );
    if (videos.isEmpty) return;
    final fc = videos.first.folderCode;
    if (fc.isEmpty) return;
    final fv = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [fc],
      orderBy: 'created_at ASC',
    );
    if (mounted) setState(() => _folderVideosOverride = fv);
  }

  Future<void> _checkAndInitializeTranslation(
    PlayerEngineNotifier notifier,
  ) async {
    final subtitles = notifier.subtitles;
    if (subtitles.isEmpty) return;

    final subState = ref.read(subscriptionProvider);
    final needCount = TranslationInitService.countNeedTranslate(
      subtitles,
      subState.mode,
    );
    if (needCount == 0) return;

    _translationInProgress = true;

    if (!mounted) return;
    // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
    TDToast.showText('正在进行翻译初始化...', context: context);

    final currentTitle = notifier.currentVideo?.name ?? widget.videoCode;

    try {
      await TranslationInitService.translateSubtitles(
        subtitles: subtitles,
        videoCode: widget.videoCode,
        title: currentTitle,
        mode: subState.mode,
        onProgress: (current, total) {},
      );
      if (mounted) setState(() {});
    } catch (e) {
      dev.log('Translation init failed: $e', name: 'PlayerPage');
      if (mounted) {
        // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
        TDToast.showFail('翻译初始化失败: $e', context: context);
      }
    } finally {
      _translationInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerEngineProvider);
    final notifier = ref.read(playerEngineProvider.notifier);
    final subtitlesList = notifier.subtitles;
    final isPad = Adaptive.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final hasSubtitles = subtitlesList.isNotEmpty;
    final idx = state.currentSubtitleIndex;
    final currentSub =
        (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;
    final drawerOpen = _showVideoList;
    final colors = context.colors;
    final topPadding = MediaQuery.of(context).padding.top;

    // iPad 横屏：70/30 分栏
    if (isPad && isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // 播放器 70%
            Expanded(
              flex: 7,
              child: _buildPlayerStack(
                state,
                notifier,
                subtitlesList,
                hasSubtitles,
                idx,
                currentSub,
                drawerOpen,
                topPadding,
                isPad,
                colors,
              ),
            ),
            // 右侧 30% 推荐/列表
            Expanded(
              flex: 3,
              child: _buildRecommendationPanel(state, notifier, colors),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildPlayerStack(
        state,
        notifier,
        subtitlesList,
        hasSubtitles,
        idx,
        currentSub,
        drawerOpen,
        topPadding,
        isPad,
        colors,
      ),
    );
  }

  Widget _buildPlayerStack(
    PlayerEngineState state,
    PlayerEngineNotifier notifier,
    List<Subtitles> subtitlesList,
    bool hasSubtitles,
    int? idx,
    Subtitles? currentSub,
    bool drawerOpen,
    double topPadding,
    bool isPad,
    AppColorsData colors,
  ) {
    return GestureDetector(
      onTap: _showControls,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // 视频层
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: VideoWidget(
                player: notifier.player,
                fit: BoxFit.contain,
                backgroundColor: Colors.black,
              ),
            ),
          ),

          // 顶部栏（BackdropFilter + 半透明）
          if (_controlsVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding:
                        EdgeInsets.only(
                          top: topPadding > 0 ? topPadding : 32,
                          bottom: 8,
                        ) +
                        EdgeInsets.symmetric(horizontal: _horizontalMargin),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _unlockOrientation();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: SizedBox(
                              width: Adaptive.w(context, 44),
                              height: Adaptive.h(context, 44),
                              child: Icon(
                                AppIcons.arrowBackIosNew,
                                color: Colors.white,
                                size: Adaptive.icon(context, 20),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            state.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: Adaptive.sp(context, 16),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _showVideoList = !_showVideoList);
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              height: Adaptive.h(context, 44),
                              padding: EdgeInsets.only(
                                left: Adaptive.w(context, 16),
                              ),
                              alignment: Alignment.centerRight,
                              child: Icon(
                                AppIcons.formatListBulleted,
                                color: _showVideoList
                                    ? colors.primary
                                    : Colors.white,
                                size: Adaptive.icon(context, 24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 底部控制区（BackdropFilter + 半透明）
          if (_controlsVisible && !drawerOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: _buildBottomArea(
                      state,
                      notifier,
                      subtitlesList,
                      isPad,
                      hasSubtitles,
                      idx,
                      currentSub,
                      colors,
                    ),
                  ),
                ),
              ),
            ),

          // 抽屉遮罩
          if (drawerOpen && !_showWordPopup)
            GestureDetector(
              onTap: () => setState(() => _showVideoList = false),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

          // 抽屉面板
          if (drawerOpen && !_showWordPopup)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 400 : 320,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      left: false,
                      child: _buildVideoListContent(state, notifier, colors),
                    ),
                  ),
                ),
              ),
            ),

          // 跟读弹窗
          if (_showReadAloud)
            _buildNewShadowReader(state, notifier, currentSub, isPad),

          // 控件隐藏时的点击恢复层（必须置于最顶层）
          if (!_controlsVisible && !drawerOpen && !_showReadAloud)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _showControls,
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  /// iPad 横屏右侧推荐面板
  Widget _buildRecommendationPanel(
    PlayerEngineState state,
    PlayerEngineNotifier notifier,
    AppColorsData colors,
  ) {
    final list = state.folderVideos.isNotEmpty
        ? state.folderVideos
        : (_folderVideosOverride ?? const <VideoInfo>[]);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(Adaptive.w(context, 16)),
            child: Row(
              children: [
                Text(
                  '推荐视频',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: Adaptive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      '暂无推荐',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(Adaptive.w(context, 12)),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _VideoListItem(
                      video: list[i],
                      isCurrent: list[i].code == state.videoCode,
                      onTap: () {
                        final code = list[i].code;
                        if (code != null && code != state.videoCode) {
                          setState(() => _showVideoList = false);
                          notifier.switchToVideo(code);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double get _horizontalMargin {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final insets = MediaQuery.of(context).padding;
    final safeSide = (w > h) ? insets.left.toDouble() : 16.0;
    return safeSide > 0 ? safeSide : 16.0;
  }

  Widget _buildBottomArea(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    List<Subtitles> sl,
    bool t,
    bool hs,
    int? idx,
    Subtitles? cs,
    AppColorsData colors,
  ) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final playbackControls = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isPortrait
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (hs)
          _smallCtrl(
            AppIcons.skipPrevious,
            (idx ?? 0) > 0
                ? () {
                    _showControls();
                    n.previousSentence();
                  }
                : null,
            t,
          ),
        _smallCtrl(
          s.playerState == PlayerState.playing ? AppIcons.pause : AppIcons.play,
          () {
            _showControls();
            n.togglePlayPause();
          },
          t,
          size: isPortrait ? 40 : 32,
        ),
        if (hs)
          _smallCtrl(
            AppIcons.skipNext,
            (idx ?? 0) < sl.length - 1
                ? () {
                    _showControls();
                    n.nextSentence();
                  }
                : null,
            t,
          ),
      ],
    );

    final featureButtons = <Widget>[
      if (hs)
        _plainTextBtn("跟读", _showReadAloud, () {
          _showControls();
          if (_translationInProgress) {
            // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
            TDToast.showWarning('翻译进行中，请稍后再试', context: context);
            return;
          }
          final shouldBeOpen = !_showReadAloud;
          if (shouldBeOpen) {
            n.player.pause();
            n.setSingleSentencePause(true);
            if (cs != null) {
              n.seekToMs(
                Duration(milliseconds: cs.startPosition.toInt()).inMilliseconds,
              );
              Future.microtask(() => n.player.play());
            }
          }
          setState(() => _showReadAloud = shouldBeOpen);
        }, colors),
      if (hs)
        _plainTextBtn(
          "清晰朗读",
          _isTtsSpeaking,
          hs
              ? () {
                  _showControls();
                  if (_isTtsSpeaking) {
                    _stopClaritySpeak(n);
                  } else if (cs != null) {
                    _handleClaritySpeak(n, s, cs);
                  }
                }
              : null,
          colors,
        ),
      if (hs)
        _plainTextBtn("字幕", s.subtitleVisible, () {
          _showControls();
          n.toggleSubtitleVisible();
        }, colors),
      if (hs)
        _plainTextBtn("翻译", s.translateVisible, () {
          _showControls();
          n.toggleTranslateVisible();
        }, colors),
      if (hs)
        _plainTextBtn("单句暂停", s.singleSentencePause, () {
          _showControls();
          n.toggleSingleSentencePause();
        }, colors),
      if (hs)
        _plainTextBtn("由慢到快", s.slowToFastActive, () {
          _showControls();
          n.toggleSlowToFastCurrentSentence();
        }, colors),
      _buildLoopModePopup(s, n, colors),
      _buildFontSizePopupButton(s, n, colors),
      _buildSpeedPopup(s, n, colors),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cs != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
            child: _buildSelectableSubtitle(s, cs, t, colors),
          ),
        SizedBox(height: isPortrait ? 8 : 4),
        _buildProgressBarWithTime(s, n, colors),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _horizontalMargin,
            vertical: isPortrait ? 8 : 4,
          ),
          child: isPortrait
              ? Column(
                  children: [
                    playbackControls,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: featureButtons,
                    ),
                  ],
                )
              : Row(
                  children: [
                    playbackControls,
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: featureButtons
                              .map(
                                (btn) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: btn,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: isPortrait ? 20 : 12),
      ],
    );
  }

  void _handleClaritySpeak(
    PlayerEngineNotifier n,
    PlayerEngineState s,
    Subtitles cs,
  ) async {
    final wasPlaying = s.playerState == PlayerState.playing;
    if (wasPlaying) n.player.pause();
    setState(() => _isTtsSpeaking = true);
    final subState = ref.read(subscriptionProvider);
    await TtsService().speakClarity(
      text: cs.content,
      mode: subState.mode,
      onComplete: () {
        if (!mounted) return;
        setState(() => _isTtsSpeaking = false);
        if (wasPlaying && !ref.read(playerEngineProvider).singleSentencePause) {
          n.player.play();
        }
      },
    );
  }

  void _stopClaritySpeak(PlayerEngineNotifier n) {
    TtsService().stop();
    setState(() => _isTtsSpeaking = false);
  }

  Widget _smallCtrl(
    IconData icon,
    VoidCallback? onTap,
    bool t, {
    double size = 28,
  }) {
    // 参考首页图标标准，iPad 上放大
    final actualSize = isIPad(context) ? size * 1.35 : size;
    final padding = isIPad(context) ? 12.0 : 8.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(actualSize + padding),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Icon(
            icon,
            color: onTap != null ? Colors.white : Colors.white24,
            size: actualSize,
          ),
        ),
      ),
    );
  }

  Widget _plainTextBtn(
    String label,
    bool active,
    VoidCallback? onTap,
    AppColorsData colors,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(context, 4),
            vertical: Adaptive.h(context, 6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? colors.primary
                  : (onTap == null ? Colors.white24 : Colors.white70),
              fontSize: Adaptive.sp(context, 14),
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _loopModeLabel(String mode) {
    switch (mode) {
      case 'single_loop':
        return '单集循环';
      case 'list_loop':
        return '列表循环';
      case 'single_play':
        return '单集播放';
      case 'sequence_play':
        return '顺序播放';
      default:
        return '单集循环';
    }
  }

  Widget _buildLoopModePopup(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    return PopupMenuButton<String>(
      initialValue: s.loopingMode,
      onSelected: (mode) {
        _showControls();
        n.setLoopingMode(mode);
      },
      offset: const Offset(0, -220),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: _plainTextBtn(
        _loopModeLabel(s.loopingMode),
        s.loopingMode != 'single_play',
        null,
        colors,
      ),
      itemBuilder: (ctx) => _playModeOptions.map((opt) {
        final active = s.loopingMode == opt['value'];
        return PopupMenuItem<String>(
          value: opt['value'],
          height: isIPad(context) ? 44 : 36,
          child: Center(
            child: Text(
              opt['label']!,
              style: TextStyle(
                color: active ? colors.primary : Colors.white,
                fontSize: Adaptive.sp(context, 14),
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpeedPopup(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    return PopupMenuButton<double>(
      initialValue: s.speed,
      onSelected: (sp) {
        _showControls();
        n.setSpeed(sp);
      },
      offset: const Offset(0, -220),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: _plainTextBtn(
        "${s.speed.toString().replaceAll(RegExp(r'\.0$'), '')}X",
        s.speed != 1.0,
        null,
        colors,
      ),
      itemBuilder: (ctx) => _speedOptions.map((sp) {
        final active = s.speed == sp;
        return PopupMenuItem<double>(
          value: sp,
          height: isIPad(context) ? 44 : 36,
          child: Center(
            child: Text(
              '${sp}X',
              style: TextStyle(
                color: active ? colors.primary : Colors.white,
                fontSize: Adaptive.sp(context, 14),
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectableSubtitle(
    PlayerEngineState s,
    Subtitles sub,
    bool t,
    AppColorsData colors,
  ) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.subtitleVisible && sub.content.isNotEmpty)
              SelectableEnglishLine(
                text: sub.content,
                fontSize: s.subtitleFontSize,
                fontColor: Colors.white,
                selectedBgColor: colors.primary.withValues(alpha: 0.7),
                onStartSelection: () => setState(() => _showWordPopup = false),
                onSelectionChanged: (words) {
                  if (words.isNotEmpty) {
                    final selectedText = words.join(' ');
                    final notifier = ref.read(playerEngineProvider.notifier);
                    final wasPlaying =
                        ref.read(playerEngineProvider).playerState ==
                        PlayerState.playing;
                    notifier.player.pause();
                    final subState = ref.read(subscriptionProvider);
                    final isPremium = subState.mode == SubscriptionMode.premium;
                    final state2 = ref.read(playerEngineProvider);
                    final currentSub = _getCurrentSubtitle();
                    final canSave = WordBookService.isSingleWord(selectedText);
                    WordCard.show(
                      context,
                      word: selectedText,
                      contextSentence: currentSub?.content,
                      isPaidMode: isPremium,
                      onSpeak: () => _speakSelectedWord(selectedText),
                      onSaveWord: canSave ? _handleSaveWord : null,
                      sourceType: 'video',
                      sourceCode: widget.videoCode,
                      sourceTitle: state2.title,
                      segmentCode: currentSub?.code,
                    ).then((_) {
                      if (wasPlaying && mounted) notifier.player.play();
                    });
                  }
                },
              ),
            if (s.translateVisible &&
                sub.contentTranslate != null &&
                sub.contentTranslate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  sub.contentTranslate!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: s.subtitleFontSize - 2,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleSaveWord({
    required String word,
    String? contextSentence,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
  }) async {
    final notifier = ref.read(playerEngineProvider.notifier);
    final state = ref.read(playerEngineProvider);
    final video = notifier.currentVideo;
    final currentSub = _getCurrentSubtitle();
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

  Subtitles? _getCurrentSubtitle() {
    final notifier = ref.read(playerEngineProvider.notifier);
    final state = ref.read(playerEngineProvider);
    final subtitlesList = notifier.subtitles;
    final idx = state.currentSubtitleIndex;
    if (idx != null && idx >= 0 && idx < subtitlesList.length) {
      return subtitlesList[idx];
    }
    return null;
  }

  Future<void> _speakSelectedWord(String word) async {
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

  /// 进度条：4pt 高度 + 20pt 拖拽热区
  Widget _buildProgressBarWithTime(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    final p = s.duration.inMilliseconds > 0
        ? s.position.inMilliseconds / s.duration.inMilliseconds
        : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Text(
            _fmtDuration(s.position),
            style: TextStyle(
              color: Colors.white70,
              fontSize: Adaptive.sp(context, 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _showControls();
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final localX = box.globalToLocal(details.globalPosition).dx;
                final totalWidth = box.size.width;
                final fraction = (localX / totalWidth).clamp(0.0, 1.0);
                n.seekToMs((fraction * s.duration.inMilliseconds).round());
              },
              onHorizontalDragUpdate: (details) {
                _showControls();
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final localX = box.globalToLocal(details.globalPosition).dx;
                final totalWidth = box.size.width;
                final fraction = (localX / totalWidth).clamp(0.0, 1.0);
                n.seekToMs((fraction * s.duration.inMilliseconds).round());
              },
              child: Container(
                height: 20, // 热区 20pt
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: isIPad(context) ? 6.0 : 4.0,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtDuration(s.duration),
            style: TextStyle(
              color: Colors.white70,
              fontSize: Adaptive.sp(context, 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoListContent(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    final list = s.folderVideos.isNotEmpty
        ? s.folderVideos
        : (_folderVideosOverride ?? const <VideoInfo>[]);
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(context, 16),
            vertical: Adaptive.h(context, 16),
          ),
          child: Row(
            children: [
              Text(
                '视频列表',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Adaptive.sp(context, 17),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '共 ${list.length} 集',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: Adaptive.sp(context, 14),
                ),
              ),
              SizedBox(width: Adaptive.w(context, 12)),
              GestureDetector(
                onTap: () => setState(() => _showVideoList = false),
                child: Icon(
                  AppIcons.close,
                  color: Colors.white70,
                  size: Adaptive.icon(context, 24),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.videoLibrary,
                        size: Adaptive.icon(context, 52),
                        color: Colors.white24,
                      ),
                      SizedBox(height: Adaptive.h(context, 10)),
                      Text(
                        '暂无可播视频',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: Adaptive.sp(context, 15),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(Adaptive.w(context, 12)),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _VideoListItem(
                    video: list[i],
                    isCurrent: list[i].code == s.videoCode,
                    onTap: () {
                      final code = list[i].code;
                      if (code != null && code != s.videoCode) {
                        setState(() => _showVideoList = false);
                        n.switchToVideo(code);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ─── 字体大小弹窗 ────────────────────
  final GlobalKey _fontSizeBtnKey = GlobalKey();
  OverlayEntry? _fontSizeOverlayEntry;

  Widget _buildFontSizePopupButton(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    return GestureDetector(
      key: _fontSizeBtnKey,
      onTap: () => _showFontSizePicker(s, n, colors),
      child: _plainTextBtn("字号", s.subtitleFontSize != 18.0, null, colors),
    );
  }

  void _showFontSizePicker(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    _hideFontSizePicker();
    final renderBox =
        _fontSizeBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final left = offset.dx + size.width / 2 - 24;
    final bottom = MediaQuery.of(context).size.height - offset.dy + 8;

    _fontSizeOverlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        onTap: _hideFontSizePicker,
        behavior: HitTestBehavior.translucent,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.transparent)),
              Positioned(
                left: left,
                bottom: bottom,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 48,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildVerticalFontSlider(s, n, colors),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_fontSizeOverlayEntry!);
  }

  void _hideFontSizePicker() {
    _fontSizeOverlayEntry?.remove();
    _fontSizeOverlayEntry = null;
  }

  Widget _buildVerticalFontSlider(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    AppColorsData colors,
  ) {
    return SizedBox(
      height: 180,
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'A',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 20),
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          SizedBox(height: Adaptive.h(context, 4)),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: colors.primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: colors.primary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: s.subtitleFontSize,
                  min: 12,
                  max: 40,
                  onChanged: (v) {
                    _showControls();
                    n.setSubtitleFontSize(v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 14),
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildNewShadowReader(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    Subtitles? cs,
    bool isPad,
  ) {
    if (cs == null) return const SizedBox.shrink();
    final video = n.currentVideo;
    final lang = video?.language ?? 'en';
    final code = s.videoCode ?? '';
    final subState = ref.read(subscriptionProvider);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    Future<void> playAtSubtitleIndex(int index) async {
      if (index < 0 || index >= n.subtitles.length) return;
      final sub = n.subtitles[index];
      await n.seekToMs(
        Duration(milliseconds: sub.startPosition.toInt()).inMilliseconds,
      );
      await n.player.play();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ShadowReaderComponent.inline(
        config: ShadowReaderConfig(
          subtitle: cs,
          resourceType: 'video',
          resourceCode: code,
          resourceTitle: s.title,
          language: lang,
          scope: 'sentence',
          getPosition: () => s.position,
          seekTo: (d) async => n.seekToMs(d.inMilliseconds),
          togglePlayPause: () async => n.togglePlayPause(),
          pause: () async => n.player.pause(),
          play: () async => n.player.play(),
          setOriginalVolume: (v) async => n.setOriginalVolume(v),
          setSpeed: (v) async => n.setSpeed(v),
          currentSpeed: s.speed,
          getSingleSentencePause: s.singleSentencePause,
          setSingleSentencePause: (v) async => n.setSingleSentencePause(v),
          setRecording: (v) async => n.setRecording(v),
          setLastFollowScore: (v) async => n.setLastFollowScore(v),
          getCurrentVideo: () => video,
          speakSubtitle: (text) async {
            final subState = ref.read(subscriptionProvider);
            await TtsService().speakSubtitle(text, mode: subState.mode);
          },
          isTtsSpeaking: _isTtsSpeaking,
          onScore: ({
            required overall,
            required fluency,
            required accuracy,
            required completeness,
            required rawResult,
          }) async {},
          onAiEvaluation: ({
            required resourceCode,
            required resourceTitle,
            required language,
            required overallScore,
            required summary,
          }) async {},
          getHeadphoneMode: null,
          currentSubtitleIndex: s.currentSubtitleIndex,
          nextSentence: () async => n.nextSentence(),
          previousSentence: () async => n.previousSentence(),
          playAtSubtitleIndex: playAtSubtitleIndex,
          subscriptionMode: subState.mode,
        ),
        heightFactor: isLandscape ? (isPad ? 0.5 : 0.6) : 0.55,
        onClose: () => setState(() => _showReadAloud = false),
      ),
    );
  }
}

// ─── _VideoListItem ────────────────────────────
class _VideoListItem extends ConsumerStatefulWidget {
  final VideoInfo video;
  final bool isCurrent;
  final VoidCallback onTap;
  const _VideoListItem({
    required this.video,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  ConsumerState<_VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends ConsumerState<_VideoListItem> {
  String? _resolvedCoverPath;

  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  @override
  void didUpdateWidget(_VideoListItem old) {
    super.didUpdateWidget(old);
    if (old.video.cover != widget.video.cover ||
        old.video.currentCover != widget.video.currentCover) {
      _resolveCover();
    }
  }

  Future<void> _resolveCover() async {
    final cover =
        (widget.video.currentCover != null &&
            widget.video.currentCover!.isNotEmpty)
        ? widget.video.currentCover
        : widget.video.cover;
    if (cover == null || cover.isEmpty) return;
    final fp = await ThumbnailService.getFullPath(cover);
    if (mounted) setState(() => _resolvedCoverPath = fp);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final cur = widget.isCurrent;
    final cover = _resolvedCoverPath;
    final colors = context.colors;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset((1 - value) * 12, 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: Adaptive.h(context, 8)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: cur
                    ? colors.primary.withValues(alpha: 0.12)
                    : Colors.grey[850],
                border: cur
                    ? Border.all(
                        color: colors.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: isIPad(context) ? 130 : 110,
                      height: isIPad(context) ? 88 : 76,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          (cover != null && File(cover).existsSync())
                              ? Image.file(
                                  File(cover),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _placeholder(),
                                )
                              : _placeholder(),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: v.hasSubtitles
                                    ? colors.primary
                                    : Colors.black.withValues(alpha: 0.5),
                              ),
                              child: Icon(
                                AppIcons.subtitles,
                                size: Adaptive.icon(
                                  context,
                                  isIPad(context) ? 13 : 10,
                                ),
                                color: v.hasSubtitles
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ),
                          if (cur)
                            Positioned(
                              top: 4,
                              left: v.hasSubtitles ? 24 : 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: colors.primary,
                                ),
                                child: Text(
                                  '播放中',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Adaptive.sp(
                                      context,
                                      isIPad(context) ? 11 : 9,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(Adaptive.w(context, 8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            v.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: Adaptive.sp(
                                context,
                                isIPad(context) ? 17 : 15,
                              ),
                              fontWeight: cur
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                AppIcons.schedule,
                                size: Adaptive.sp(context, 14),
                                color: Colors.white70,
                              ),
                              SizedBox(width: Adaptive.w(context, 4)),
                              Text(
                                v.durationString,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: Adaptive.sp(
                                    context,
                                    isIPad(context) ? 15 : 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(
      AppIcons.movie,
      size: Adaptive.icon(context, 48),
      color: Colors.white24,
    ),
  );
}
