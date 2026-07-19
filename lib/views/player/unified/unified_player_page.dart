import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:record/record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/views/player/unified/providers/player_engine_provider.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/utils/app_globals.dart';
import 'package:vidlang/views/word_book/widgets/word_card.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'unified_player_logic.dart';
import 'widgets/media_area.dart';
import 'widgets/top_bar.dart';
import 'widgets/bottom_controls.dart';
import 'widgets/side_drawer.dart';
import 'widgets/follow_panel_widget.dart';
import 'widgets/unified_picker.dart';

/// 统一播放器页面
///
/// 通过 [audioType] 区分资源类型：
/// - `null` 或 `'video'` → 视频模式（VideoWidget + 可选字幕）
/// - `'music'` 或 `'podcast'` 等 → 音频模式（模糊封面 + 字幕列表）
///
/// **屏幕方向管理**（参考 VideoPlayerBase 极简模式）：
/// - initState() 允许所有方向旋转 + 开启屏幕常亮
/// - didChangeMetrics() 监听方向变化 → 切换沉浸式模式
/// - build() 直接使用 MediaQuery.of(context).orientation 判断布局
/// - dispose() 关闭屏幕常亮 + 清理资源
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

  /// 是否处于全屏横屏模式（不改变系统方向，仅切换布局）
  bool _fullscreenLandscape = false;

  /// 解析后的封面路径（音频模式）
  String? _resolvedCoverPath;

  /// 文件夹视频列表（覆盖 state 中的）
  List<VideoInfo>? _folderVideosOverride;

  /// 初始化完成标记
  bool _initialized = false;

  /// 翻译进行中
  bool _translationInProgress = false;

  // 浮动弹出面板 OverlayEntry
  OverlayEntry? _speedPanelEntry;
  OverlayEntry? _loopPanelEntry;
  OverlayEntry? _fontSizePanelEntry;

  /// 按钮 GlobalKey（传递给 BottomControls，供面板定位）
  final GlobalKey _speedKey = GlobalKey();
  final GlobalKey _fontSizeKey = GlobalKey();
  final GlobalKey _loopKey = GlobalKey();

  // 录音相关状态
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _autoStopTimer;

  // ─── 逻辑助手 ──────────────────────────────────────

  late final UnifiedPlayerLogic _logic;

  // ─── 生命周期 ──────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // ✅ 关键1：添加 WidgetsBindingObserver（监听 didChangeMetrics）
    WidgetsBinding.instance.addObserver(this);

    // ✅ 关键2：允许所有方向旋转（与参考代码完全一致）
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // ✅ 关键3：开启屏幕常亮（与参考代码完全一致）
    WakelockPlus.enable();
    debugPrint('🎬 [initState] WakelockPlus.enable called');

    // 延迟到第一帧后再初始化 logic 和播放器，确保 Overlay 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 🎯 初始化时应用沉浸式模式（如果当前是横屏）
      final initialOrientation = MediaQuery.of(context).orientation;
      debugPrint('🎯 [initState] 初始方向: $initialOrientation');
      _handleOrientationChange(initialOrientation);

      _logic = UnifiedPlayerLogic(
        ref: ref,
        mounted: () => mounted,
        setState: (fn) {
          if (mounted) setState(fn);
        },
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
    debugPrint('🗑️ [dispose] 开始清理资源');

    // ✅ 移除 Observer
    WidgetsBinding.instance.removeObserver(this);

    // ✅ 取消定时器
    _autoStopTimer?.cancel();

    // ✅ 释放录音器
    _recorder.dispose();

    // ✅ 关闭屏幕常亮（与参考代码完全一致）
    WakelockPlus.disable();
    debugPrint('🗑️ [dispose] WakelockPlus.disable called');

    // ✅ 恢复屏幕方向为竖屏（退出播放器时）
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugPrint('🗑️ [dispose] 恢复竖屏方向');

    // ✅ 清理逻辑层
    _logic.dispose();

    // ✅ 清理浮动面板 OverlayEntry
    _speedPanelEntry?.remove();
    _speedPanelEntry = null;
    _loopPanelEntry?.remove();
    _loopPanelEntry = null;
    _fontSizePanelEntry?.remove();
    _fontSizePanelEntry = null;

    super.dispose();
    debugPrint('🗑️ [dispose] 清理完成');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _logic.handleAppLifecyclePaused();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 屏幕方向监听（与参考代码 VideoPlayerBase 完全一致）
  // ═══════════════════════════════════════════════════════════

  /// 监听物理旋转和显示属性变化（核心方法！）
  ///
  /// **参考代码位置**：VideoPlayerBase.didChangeMetrics() (line 1902)
  /// **执行流程**：
  /// 1. 等待 MediaQuery 更新完成（microtask + postFrameCallback）
  /// 2. 读取当前方向 MediaQuery.of(context).orientation
  /// 3. 调用 _handleOrientationChange() 处理 UI 模式切换
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    // 检查 Widget 是否已挂载
    if (!mounted) return;

    debugPrint('📐 [didChangeMetrics] ⚡️ 被触发！');

    // 延迟执行，确保 MediaQuery 更新完成（与参考代码完全一致）
    Future.microtask(() {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          final orientation = MediaQuery.of(context).orientation;
          debugPrint('📱 [didChangeMetrics] 屏幕方向变化：$orientation');
          _handleOrientationChange(orientation);
        } catch (e) {
          debugPrint('⚠️ [didChangeMetrics] 获取屏幕方向失败: $e');
        }
      });
    });
  }

  /// 处理屏幕方向变化，自动切换全屏模式（核心方法！）
  ///
  /// **参考代码位置**：VideoPlayerBase._handleOrientationChange() (line 1928)
  /// **逻辑**：
  /// - 横屏 → 隐藏状态栏和导航栏（immersiveSticky）
  /// - 竖屏 → 显示状态栏和导航栏（manual + all overlays）
  void _handleOrientationChange(Orientation orientation) {
    debugPrint('🔄 [_handleOrientationChange] orientation=$orientation');

    if (orientation == Orientation.landscape) {
      // 横屏：进入全屏模式（隐藏状态栏和导航栏）
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [], // 隐藏所有系统UI
      );
      debugPrint('✅ [_handleOrientationChange] 已切换到横屏全屏模式');
    } else {
      // 竖屏：恢复正常模式（显示状态栏和导航栏）
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // 显示所有系统UI
      );
      debugPrint('✅ [_handleOrientationChange] 已恢复竖屏正常模式');
    }

    // 触发 UI 重绘（使用新的 orientation 重新布局）
    if (mounted) {
      setState(() {});
    }
  }

  // ─── 初始化 ────────────────────────────────────────

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
      await _logic.resolveCover(
        onResolved: (path) {
          if (mounted) _resolvedCoverPath = path;
        },
      );
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
    final currentSub =
        (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;
    final colors = context.colors;
    final isPad = AppGlobals.isTablet;

    // ✅ 关键改进：直接使用 MediaQuery.of(context).orientation（与参考代码一致）
    // 不再依赖全局状态 _isLandscapeMode，完全由系统驱动
    // 全屏模式下强制横屏布局，不改变系统方向
    final isLandscape = _fullscreenLandscape ||
        MediaQuery.of(context).orientation == Orientation.landscape;

    // 详细日志：每次 build 都输出当前状态（方便排查布局问题）
    debugPrint(
      '🏗️ UnifiedPlayerPage.build: '
      'isLandscape=$isLandscape, '
      'isPad=$isPad, '
      'hasSubtitles=$hasSubtitles, '
      'currentSubtitleIndex=$idx, '
      '_showDrawer=$_showDrawer, '
      '_settingsExpanded=$_settingsExpanded, '
      '_showFollow=$_showFollow',
    );

    // iPad 横屏：70/30 分栏布局
    if (isPad && isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Row(
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
                  onSwitchTo: (code) {
                    _switchResource(code, notifier);
                  },
                  onClose: () {},
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // 统一黑色背景，沉浸式
      resizeToAvoidBottomInset: false, // 不因键盘/导航栏调整布局
      extendBodyBehindAppBar: true, // body 延伸到 AppBar 后面
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
          onWordSelected: (words, sub) =>
              _handleWordSelected(words, sub, state, notifier),
          onToggleFullscreen: widget.isVideo ? _toggleFullscreen : null,
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TopBar(
            title: state.title,
            isLandscape: isLandscape,
            onBack: _handleBack, // ✅ 使用统一的返回处理方法
            onToggleDrawer: () {
              if (!showDrawerPermanent)
                setState(() => _showDrawer = !_showDrawer);
            },
            isDrawerOpen: _showDrawer,
            // 横屏时为右上角全屏按钮让出空间（裁掉该区域背景 + 右移列表/设置按钮）
            trailingRightInset: isLandscape ? adaptive.Adaptive.w(56) : 0.0,
          ),
        ),

        // 🎯 全屏切换按钮（位于屏幕左上角，返回按钮旁边）
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
            onToggleFollow: () =>
                _handleToggleFollow(notifier, state, currentSub),
            onClaritySpeak: (currentSub != null)
                ? () => _handleClaritySpeak(notifier, state, currentSub)
                : null,
            onStopSpeak: () => _handleStopSpeak(),
            onToggleSettings: () =>
                setState(() => _settingsExpanded = !_settingsExpanded),
            onWordSelected: (words, sub) =>
                _handleWordSelected(words, sub, state, notifier),
            onShowSpeedPicker: (ctx) => _toggleSpeedPicker(ctx),
            onShowFontSizePicker: (ctx) => _toggleFontSizePicker(ctx),
            onShowLoopPicker: (ctx) => _toggleLoopModePicker(ctx),
            onToggleFullscreen: _toggleFullscreen,
            speedKey: _speedKey,
            fontSizeKey: _fontSizeKey,
            loopKey: _loopKey,
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
              currentSub: currentSub,
              onClose: () {
                setState(() => _showFollow = false);
                notifier.exitFollowMode();
              },
            ),
          ),

        // 竖屏模式下：仅当用户主动点击列表按钮时才显示滑出式侧边栏
        // 横屏 iPad 模式下：使用永久固定侧边栏（由 showDrawerPermanent 控制）
        if (_showDrawer && !showDrawerPermanent && !isLandscape)
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

        // 右侧浮动按钮组（圆形黑底按钮，仅字幕模式显示）
        // 按钮顺序（从上到下）：跟读、清晰朗读(TTS)、由慢到快
        // 位置：字幕区域右侧中间（竖屏模式下）
        if (hasSubtitles && !_showDrawer)
          Positioned(
            right: adaptive.Adaptive.w(12),
            // 字幕区域中间位置：视频区域下方 + 字幕区域高度的 50%
            top:
                MediaQuery.of(context).size.height * 0.5 -
                adaptive.Adaptive.h(140) * 0.5,
            child: _FloatingActionButtons(
              isTtsSpeaking: _isTtsSpeaking,
              slowToFastActive: state.slowToFastActive,
              showFollow: _showFollow,
              onToggleFollow: () =>
                  _handleToggleFollow(notifier, state, currentSub),
              onClaritySpeak: (currentSub != null)
                  ? () => _handleClaritySpeak(notifier, state, currentSub)
                  : null,
              onStopSpeak: _handleStopSpeak,
              onToggleSlowToFast: () =>
                  notifier.toggleSlowToFastCurrentSentence(),
            ),
          ),
      ],
    );
  }

  // ─── 回调处理 ─────────────────────────────────────

  bool get _showFollowPanelBlocked => _showDrawer;

  /// 统一的返回按钮处理（与参考代码 _handlePopInvoked 一致）
  ///
  /// **逻辑**：
  /// - 横屏时：先恢复竖屏，阻止返回
  /// - 竖屏时：正常返回上一页
  void _handleBack() {
    final orientation = MediaQuery.of(context).orientation;

    debugPrint('🔙 [_handleBack] 当前方向: $orientation');

    if (orientation == Orientation.landscape) {
      // ✅ 横屏时：先恢复竖屏（与参考代码 RotationReset 一致）
      debugPrint('🔙 [_handleBack] 横屏 → 先恢复竖屏，阻止返回');
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // 不执行返回操作，等待用户再次点击返回
      return;
    }

    // ✅ 竖屏时：正常返回
    debugPrint('🔙 [_handleBack] 竖屏 → 正常返回');
    Navigator.pop(context);
  }

  /// 全屏切换按钮处理
  void _toggleFullscreen() {
    debugPrint('🔄 [_toggleFullscreen] 按钮被点击！');
    debugPrint('🔄 [_toggleFullscreen] 当前全屏横屏=$_fullscreenLandscape');

    setState(() {
      _fullscreenLandscape = !_fullscreenLandscape;
    });

    debugPrint('🔄 [_toggleFullscreen] 切换为全屏横屏=$_fullscreenLandscape');
  }

  // ═══════════════════════════════════════════════════════════
  // 浮动弹出面板管理
  // ═══════════════════════════════════════════════════════════

  void _toggleSpeedPicker(BuildContext context) {
    if (_speedPanelEntry != null) {
      _speedPanelEntry!.remove();
      _speedPanelEntry = null;
    } else {
      _speedPanelEntry = showSpeedPanel(
        context,
        currentSpeed: ref.read(playerEngineProvider).speed,
        speeds: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        targetKey: _speedKey,
        onSelected: (speed) {
          ref.read(playerEngineProvider.notifier).setSpeed(speed);
        },
      );
    }
  }

  void _toggleFontSizePicker(BuildContext context) {
    if (_fontSizePanelEntry != null) {
      _fontSizePanelEntry!.remove();
      _fontSizePanelEntry = null;
    } else {
      _fontSizePanelEntry = showFontSizePanel(
        context,
        fontSize: ref.read(playerEngineProvider).subtitleFontSize,
        targetKey: _fontSizeKey,
        onChanged: (size) {
          ref.read(playerEngineProvider.notifier).setSubtitleFontSize(size);
        },
      );
    }
  }

  void _toggleLoopModePicker(BuildContext context) {
    if (_loopPanelEntry != null) {
      _loopPanelEntry!.remove();
      _loopPanelEntry = null;
    } else {
      const modes = [
        {'label': '单集循环', 'value': 'single_loop'},
        {'label': '列表循环', 'value': 'list_loop'},
        {'label': '单集播放', 'value': 'single_play'},
        {'label': '顺序播放', 'value': 'sequence_play'},
      ];
      _loopPanelEntry = showLoopPanel(
        context,
        currentMode: ref.read(playerEngineProvider).loopingMode,
        modes: modes,
        targetKey: _loopKey,
        onSelected: (mode) {
          ref.read(playerEngineProvider.notifier).setLoopingMode(mode);
        },
      );
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
      await _logic.resolveCover(
        onResolved: (path) {
          if (mounted) _resolvedCoverPath = path;
        },
      );
    }
    if (mounted) setState(() {});
  }

  void _handleToggleFollow(
    PlayerEngineNotifier n,
    PlayerEngineState s,
    Subtitles? cs,
  ) {
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

  void _handleClaritySpeak(
    PlayerEngineNotifier n,
    PlayerEngineState s,
    Subtitles cs,
  ) {
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

  void _handleWordSelected(
    List<String> words,
    Subtitles sub,
    PlayerEngineState s,
    PlayerEngineNotifier n,
  ) {
    // 🔴🔴🔴 第一时间立即暂停（同步，不等待）🔴🔴🔴
    // 这是用户点击的瞬间，必须立即响应！
    _immediatePauseForWordCard(n, s);

    // 异步处理后续逻辑（弹窗、查询等）
    _handleWordCardAsync(words, sub, s, n);
  }

  /// 立即暂停：在用户点击的第一时间执行（同步）
  void _immediatePauseForWordCard(PlayerEngineNotifier n, PlayerEngineState s) {
    // 1. 立即停止 TTS
    _logic.stopClaritySpeak();
    if (mounted) setState(() => _isTtsSpeaking = false);

    // 2. 立即暂停 Player（不等待，让原生层尽快收到暂停指令）
    if (s.playerState == PlayerState.playing ||
        s.playerState == PlayerState.loading) {
      debugPrint(
        '⏸️ [UnifiedPlayer] 点击单词 → 立即暂停 Player (当前状态: ${s.playerState})',
      );
      n.player.pause();
    }
  }

  /// 异步处理：弹窗展示和恢复逻辑
  Future<void> _handleWordCardAsync(
    List<String> words,
    Subtitles sub,
    PlayerEngineState s,
    PlayerEngineNotifier n,
  ) async {
    if (words.isEmpty) return;
    final selectedText = words.join(' ');
    final wasPlaying = s.playerState == PlayerState.playing;

    // 等待 Player 真正暂停（给原生层时间处理）
    await Future.delayed(const Duration(milliseconds: 150));

    // 二次确认暂停状态
    final currentstate = ref.read(playerEngineProvider);
    if (currentstate.playerState != PlayerState.paused &&
        currentstate.playerState != PlayerState.idle &&
        currentstate.playerState != PlayerState.stopped &&
        currentstate.playerState != PlayerState.completed) {
      debugPrint(
        '⚠️ [UnifiedPlayer] Player 未完全暂停 (${currentstate.playerState})，重试',
      );
      n.player.pause();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 安全打开弹窗
    if (!mounted) return;

    debugPrint('📖 [UnifiedPlayer] 打开 WordCard 弹窗: "$selectedText"');

    await WordCard.show(
      context,
      word: selectedText,
      contextSentence: sub.content,
      onSaveWord:
          ({
            required String word,
            String? contextSentence,
            required String sourceType,
            required String sourceCode,
            String? sourceTitle,
          }) async {
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
    );

    // 弹窗关闭后恢复
    if (!mounted) return;

    if (wasPlaying) {
      debugPrint('▶️ [UnifiedPlayer] WordCard 关闭 → 恢复播放');
      n.player.play();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 右侧浮动按钮组（参考图2/图3）
  // ═══════════════════════════════════════════════════════════

  /// 右侧浮动圆形按钮组（仅竖屏字幕模式显示）
  ///
  /// 按钮顺序（从上到下）：
  /// 1. 跟读（麦克风图标）
  /// 2. 清晰朗读 / TTS 停止（音量图标 / 停止图标）
  /// 3. 由慢到快（速度图标）
  Widget _FloatingActionButtons({
    required bool isTtsSpeaking,
    required bool slowToFastActive,
    required bool showFollow,
    required VoidCallback onToggleFollow,
    VoidCallback? onClaritySpeak,
    VoidCallback? onStopSpeak,
    required VoidCallback onToggleSlowToFast,
  }) {
    final btnSize = adaptive.Adaptive.w(40);
    final iconSize = adaptive.Adaptive.icon(18);
    final spacing = adaptive.Adaptive.h(8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. 跟读
        _buildFabButton(
          icon: showFollow ? AppIcons.micNone : AppIcons.mic,
          size: btnSize,
          iconSize: iconSize,
          tooltip: showFollow ? '退出跟读' : '开始跟读',
          isActive: showFollow,
          onTap: onToggleFollow,
        ),
        SizedBox(height: spacing),

        // 2. 清晰朗读(TTS) / TTS 停止
        if (!isTtsSpeaking && onClaritySpeak != null)
          _buildFabButton(
            icon: AppIcons.volumeUp,
            size: btnSize,
            iconSize: iconSize,
            tooltip: '清晰朗读(TTS)',
            onTap: onClaritySpeak,
          )
        else if (isTtsSpeaking)
          _buildFabButton(
            icon: AppIcons.stopCircle,
            size: btnSize,
            iconSize: iconSize,
            tooltip: '停止朗读',
            isActive: true,
            onTap: onStopSpeak ?? () {},
          )
        else
          SizedBox(width: btnSize, height: btnSize),
        SizedBox(height: spacing),

        // 3. 由慢到快
        _buildFabButton(
          icon: AppIcons.speed,
          size: btnSize,
          iconSize: iconSize,
          tooltip: slowToFastActive ? '取消由慢到快' : '由慢到快',
          isActive: slowToFastActive,
          onTap: onToggleSlowToFast,
        ),
      ],
    );
  }

  /// 浮动圆形按钮（黑底半透明 + 白色图标）
  Widget _buildFabButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.6),
            // border: isActive
            //     ? Border.all(color: AppColors.primary, width: 1.5)
            //     : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isActive ? AppColors.primary : Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
