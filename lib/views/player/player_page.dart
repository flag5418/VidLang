import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/services/translation_init_service.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
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

  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final List<Map<String, String>> _playModeOptions = [
    {'label': '单集循环', 'value': 'single_loop'},
    {'label': '列表循环', 'value': 'list_loop'},
    {'label': '单集播放', 'value': 'single_play'},
    {'label': '顺序播放', 'value': 'sequence_play'},
  ];

  // TTS playback
  final ap.AudioPlayer _aliAudioPlayer = ap.AudioPlayer();
  bool _isTtsSpeaking = false;

  bool _showWordPopup = false;

  // Player overlay is always dark regardless of theme mode
  Color _drawerText() => AppColors.onSurface;
  Color _drawerTextVariant() => AppColors.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockLandscape();
    _loadSettings();
    // 沉浸式状态栏：透明背景
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    Future.microtask(() => _initializePlayer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aliAudioPlayer.dispose();
    _unlockOrientation();
    _initialized = false;
    super.dispose();
  }

  void _lockLandscape() {
    // 允许用户竖屏播放
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
    // 检查并初始化翻译
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

  /// 检查并初始化翻译
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

    // 翻译期间阻止其他 DB 写入操作（跟读评分等）
    _translationInProgress = true;

    // 显示加载提示
    if (!mounted) return;
    TDMessage.showMessage(
      context: context,
      content: '正在进行翻译初始化...',
      theme: MessageTheme.info,
      duration: 2000,
      visible: true,
    );

    final currentTitle = notifier.currentVideo?.name ?? widget.videoCode;

    // 执行翻译
    try {
      await TranslationInitService.translateSubtitles(
        subtitles: subtitles,
        videoCode: widget.videoCode,
        title: currentTitle,
        mode: subState.mode,
        onProgress: (current, total) {},
      );

      if (mounted) {
        setState(() {}); // 刷新 UI 显示翻译
      }
    } catch (e) {
      dev.log('Translation init failed: $e', name: 'PlayerPage');
      if (mounted) {
        TDMessage.showMessage(
          context: context,
          content: '翻译初始化失败: $e',
          theme: MessageTheme.error,
          duration: 3000,
          visible: true,
        );
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
    final isTablet = false; // iPhone only
    final hasSubtitles = subtitlesList.isNotEmpty;
    final idx = state.currentSubtitleIndex;
    final currentSub =
        (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;
    final drawerOpen = _showVideoList;

    final topPadding = MediaQuery.of(context).padding.top;
    MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video fills screen (edge-to-edge, immersive)
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

          // Top bar (with status bar padding)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  EdgeInsets.only(
                    top: topPadding > 0 ? topPadding : 32,
                    bottom: 8,
                  ) +
                  EdgeInsets.symmetric(horizontal: _horizontalMargin),

              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // 返回按钮：扩展左侧点击区域
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _unlockOrientation();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      state.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      _topBtn(
                        Icons.format_list_bulleted_rounded,
                        () => setState(() {
                          _showVideoList = !_showVideoList;
                        }),
                        active: _showVideoList,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom area (with navigation bar padding)
          if (!drawerOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: _buildBottomArea(
                  state,
                  notifier,
                  subtitlesList,
                  isTablet,
                  hasSubtitles,
                  idx,
                  currentSub,
                ),
              ),
            ),

          // Drawer overlay
          if (drawerOpen && !_showWordPopup)
            GestureDetector(
              onTap: () => setState(() {
                _showVideoList = false;
              }),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

          // Drawer panel
          if (drawerOpen && !_showWordPopup)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 360,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.85),
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      left: false,
                      child: _buildVideoListContent(state, notifier),
                    ),
                  ),
                ),
              ),
            ),

          // Read-aloud popup
          if (_showReadAloud)
            _buildNewShadowReader(state, notifier, currentSub),
        ],
      ),
    );
  }

  double get _horizontalMargin {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    // 横屏时考虑刘海屏/圆角安全区域
    final insets = MediaQuery.of(context).padding;
    final safeSide = (w > h) ? insets.left.toDouble() : 16.0;
    return safeSide > 0 ? safeSide : 16.0;
  }

  Widget _topBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 16),
          alignment: Alignment.centerRight,
          child: Icon(
            icon,
            color: active ? AppColors.primary : Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ─── Bottom Area ────────────────────────────────
  Widget _buildBottomArea(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    List<Subtitles> sl,
    bool t,
    bool hs,
    int? idx,
    Subtitles? cs,
  ) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // 左侧组：上一句、播放、下一句
    final playbackControls = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isPortrait
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (hs)
          _smallCtrl(
            Icons.skip_previous_rounded,
            (idx ?? 0) > 0 ? () => n.previousSentence() : null,
            t,
          ),
        _smallCtrl(
          s.playerState == PlayerState.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          () => n.togglePlayPause(),
          t,
          size: isPortrait ? 40 : 32,
        ),
        if (hs)
          _smallCtrl(
            Icons.skip_next_rounded,
            (idx ?? 0) < sl.length - 1 ? () => n.nextSentence() : null,
            t,
          ),
      ],
    );

    // 右侧功能按钮组
    final featureButtons = <Widget>[
      if (hs)
        _plainTextBtn("跟读", _showReadAloud, () {
          if (_translationInProgress) {
            TDMessage.showMessage(
              context: context,
              content: '翻译进行中，请稍后再试',
              theme: MessageTheme.warning,
              duration: 1500,
              visible: true,
            );
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
        }),
      if (hs)
        _plainTextBtn(
          "清晰朗读",
          hs ? _isTtsSpeaking : false,
          hs
              ? () {
                  if (_isTtsSpeaking) {
                    _stopClaritySpeak(n);
                  } else if (cs != null) {
                    _handleClaritySpeak(n, s, cs);
                  }
                }
              : null,
        ),
      if (hs)
        _plainTextBtn("字幕", s.subtitleVisible, () => n.toggleSubtitleVisible()),
      if (hs)
        _plainTextBtn(
          "翻译",
          s.translateVisible,
          () => n.toggleTranslateVisible(),
        ),
      if (hs)
        _plainTextBtn(
          "单句暂停",
          s.singleSentencePause,
          () => n.toggleSingleSentencePause(),
        ),
      if (hs)
        _plainTextBtn(
          "由慢到快",
          s.slowToFastActive,
          () => n.toggleSlowToFastCurrentSentence(),
        ),
      // 循环模式按钮
      PopupMenuButton<String>(
        initialValue: s.loopingMode,
        onSelected: (mode) => n.setLoopingMode(mode),
        offset: const Offset(0, -220),
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: _plainTextBtn(
          _loopModeLabel(s.loopingMode),
          s.loopingMode != 'single_play',
          null,
        ),
        itemBuilder: (context) {
          return _playModeOptions.map((opt) {
            final active = s.loopingMode == opt['value'];
            return PopupMenuItem<String>(
              value: opt['value'],
              height: 36,
              child: Center(
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    color: active ? AppColors.primary : Colors.white,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList();
        },
      ),
      // 字体大小按钮（仿照倍速按钮，使用 PopupMenuButton + 竖向 Slider）
      _buildFontSizePopupButton(s, n),
      // 倍数按钮
      PopupMenuButton<double>(
        initialValue: s.speed,
        onSelected: (sp) {
          n.setSpeed(sp);
        },
        offset: const Offset(0, -220),
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: _plainTextBtn(
          "${s.speed.toString().replaceAll(RegExp(r'\.0$'), '')}X",
          s.speed != 1.0,
          null,
        ),
        itemBuilder: (context) {
          return _speedOptions.map((sp) {
            final active = s.speed == sp;
            return PopupMenuItem<double>(
              value: sp,
              height: 36,
              child: Center(
                child: Text(
                  '${sp}X',
                  style: TextStyle(
                    color: active ? AppColors.primary : Colors.white,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList();
        },
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cs != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
            child: _buildSelectableSubtitle(s, cs, t),
          ),
        // 进度条 + 两端时间
        _buildProgressBarWithTime(s, n),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _horizontalMargin,
            vertical: isPortrait ? 12 : 0,
          ),
          child: isPortrait
              ? Column(
                  children: [
                    playbackControls,
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: featureButtons,
                    ),
                  ],
                )
              : Row(
                  children: [
                    playbackControls,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: featureButtons
                                .map(
                                  (btn) => Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: btn,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: isPortrait ? 24 : 16),
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

    // 使用统一的 TtsService
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            color: onTap != null ? Colors.white : Colors.white24,
            size: size,
          ),
        ),
      ),
    );
  }

  /// 纯文字按钮（无边框、无背景，与倍数按钮样式一致）
  Widget _plainTextBtn(String label, bool active, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? AppColors.primary
                  : (onTap == null ? Colors.white24 : Colors.white70),
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 循环模式标签映射
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

  // ─── Selectable Subtitle (word-level swipe-to-select) ──
  Widget _buildSelectableSubtitle(PlayerEngineState s, Subtitles sub, bool t) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.playerSubtitleBg,
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
                selectedBgColor: AppColors.primary.withValues(alpha: 0.7),
                onStartSelection: () {
                  setState(() {
                    _showWordPopup = false;
                  });
                },
                onSelectionChanged: (words) {
                  if (words.isNotEmpty) {
                    final selectedText = words.join(' ');
                    // 暂停播放
                    final notifier = ref.read(playerEngineProvider.notifier);
                    final wasPlaying =
                        ref.read(playerEngineProvider).playerState ==
                        PlayerState.playing;
                    notifier.player.pause();
                    // 弹出查词卡片
                    final subState = ref.read(subscriptionProvider);
                    final isPremium = subState.mode == SubscriptionMode.premium;
                    final state = ref.read(playerEngineProvider);
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
                      sourceTitle: state.title,
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
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  sub.contentTranslate!,
                  style: TextStyle(
                    color: AppColors.playerSubtitleTranslate,
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

  /// 收藏单词到生词本
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

  /// 获取当前字幕
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

  /// 单词朗读：通过统一 TTS 服务自动按订阅模式分流
  /// - 免费模式 → 原生 TTS（无需 AI 模型）
  /// - 收费模式 → 云端阿里云 TTS（ai-proxy Edge Function）
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

  Widget _buildProgressBarWithTime(
    PlayerEngineState s,
    PlayerEngineNotifier n,
  ) {
    final p = s.duration.inMilliseconds > 0
        ? s.position.inMilliseconds / s.duration.inMilliseconds
        : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
      child: Row(
        children: [
          SizedBox(width: 24),
          // 左侧当前时间
          Text(
            _fmtDuration(s.position),
            style: TextStyle(
              color: Colors.white70,
              fontSize: AppTypography.fontSizeXSmall,
            ),
          ),
          const SizedBox(width: 8),
          // 进度条
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: AppColors.secondary,
                inactiveTrackColor: Colors.white10,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                thumbColor: AppColors.primary,
              ),
              child: Slider(
                value: p.clamp(0.0, 1.0),
                onChanged: (v) =>
                    n.seekToMs((v * s.duration.inMilliseconds).round()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 右侧总时长
          Text(
            _fmtDuration(s.duration),
            style: TextStyle(
              color: Colors.white70,
              fontSize: AppTypography.fontSizeXSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoListContent(PlayerEngineState s, PlayerEngineNotifier n) {
    final list = s.folderVideos.isNotEmpty
        ? s.folderVideos
        : (_folderVideosOverride ?? const <VideoInfo>[]);
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: Colors.transparent),
          child: Row(
            children: [
              Text(
                '视频列表',
                style: TextStyle(
                  color: _drawerText(),
                  fontSize: AppTypography.fontSizeSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '共 ${list.length} 集',
                style: TextStyle(
                  color: _drawerTextVariant(),
                  fontSize: AppTypography.fontSizeXSmall,
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
                        Icons.video_library_outlined,
                        size: 48,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '暂无可播视频',
                        style: TextStyle(
                          color: _drawerTextVariant(),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12),
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

  final GlobalKey _fontSizeBtnKey = GlobalKey();

  /// 字体大小调整按钮（使用 OverlayEntry 弹窗）
  Widget _buildFontSizePopupButton(
    PlayerEngineState s,
    PlayerEngineNotifier n,
  ) {
    return GestureDetector(
      key: _fontSizeBtnKey,
      onTap: () => _showFontSizePicker(s, n),
      child: _plainTextBtn("字号", s.subtitleFontSize != 18.0, null),
    );
  }

  OverlayEntry? _fontSizeOverlayEntry;

  void _showFontSizePicker(PlayerEngineState s, PlayerEngineNotifier n) {
    _hideFontSizePicker();

    final renderBox = _fontSizeBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final left = offset.dx + size.width / 2 - 24;
    final bottom = MediaQuery.of(context).size.height - offset.dy + 8;

    _fontSizeOverlayEntry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          onTap: _hideFontSizePicker,
          behavior: HitTestBehavior.translucent,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: Colors.transparent),
                ),
                // 弹窗内容
                Positioned(
                  left: left,
                  bottom: bottom,
                  child: GestureDetector(
                    onTap: () {},
                      child: Container(
                      width: 48,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildVerticalFontSlider(s, n),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_fontSizeOverlayEntry!);
  }

  void _hideFontSizePicker() {
    _fontSizeOverlayEntry?.remove();
    _fontSizeOverlayEntry = null;
  }

  /// 竖向字体大小滑条（使用 TDSlider）
  Widget _buildVerticalFontSlider(PlayerEngineState s, PlayerEngineNotifier n) {
    return SizedBox(
      height: 180,
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 大 A
          Text(
            'A',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          // 竖向 TDSlider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: TDSlider(
                value: s.subtitleFontSize,
                onChanged: (v) => n.setSubtitleFontSize(v),
                boxDecoration: const BoxDecoration(color: Colors.transparent),
                sliderThemeData: TDSliderThemeData(
                  context: context,
                  min: 12,
                  max: 40,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.surfaceElevated,
                  showThumbValue: false,
                  sliderThemeData: SliderThemeData(
                    thumbColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceElevated,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 小 A
          Text(
            'A',
            style: TextStyle(
              fontSize: 12,
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

    // 内联渲染：直接返回 Positioned Widget，不创建新路由，避免视频黑屏
    // 横屏时限制最大高度不超过 60%，确保视频区域仍然可见
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
        heightFactor: isLandscape ? 0.6 : 0.55,
        onClose: () => setState(() => _showReadAloud = false),
      ),
    );
  }
}

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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 12, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: cur
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceElevated,
                border: cur
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x15000000),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.md),
                    ),
                    child: SizedBox(
                      width: 110,
                      height: 76,
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
                          // 左上角字幕标签
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                                color: v.hasSubtitles
                                    ? AppColors.primary
                                    : Colors.black.withValues(alpha: 0.5),
                              ),
                              child: Icon(
                                Icons.subtitles,
                                size: 10,
                                color: v.hasSubtitles
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ),
                          // 左上角播放中标签 (紧跟在字幕后面)
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
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                  color: AppColors.primary,
                                ),
                                child: Text(
                                  '播放中',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
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
                      padding: EdgeInsets.all(AppSpacing.space3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            v.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: cur
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 4),
                              Text(
                                v.durationString,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: AppTypography.fontSizeXSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (cur) Container(width: 3, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.movie_outlined, size: 48, color: Colors.white24),
  );
}
