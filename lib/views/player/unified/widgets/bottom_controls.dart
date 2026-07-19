import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/views/player/unified/providers/player_engine_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/player/unified/unified_player_logic.dart';

/// 统一底部控制栏
///
/// 布局设计（V2.1 重构，参考图3）:
/// - 竖屏: 单行结构
///   [进度条(带时间)]
///   [左侧: 字幕显隐/上句/播放/下句] ... [右侧: 翻译/字幕/单句停/单句循/倍速/设置] (文字按钮，不换行)
/// - 横屏: 1行紧凑结构（不变）
///
/// 关键变更 (V2.1):
/// 1. 竖屏去掉图标+文字混用，统一为文字按钮一行排开（参考图3底部）
/// 2. 不常用功能（由慢→快/TTS/单句停）移至右侧浮动按钮组(FloatingActionButtons)
/// 3. 底部仅保留最常用的5-6个文字按钮
class BottomControls extends ConsumerWidget {
  final bool isVideo;
  final bool isLandscape;
  final PlayerEngineState state;
  final PlayerEngineNotifier notifier;
  final bool hasSubtitles;
  final Subtitles? currentSub;
  final bool showFollow;
  final bool isTtsSpeaking;
  final bool settingsExpanded;
  final VoidCallback onToggleFollow;
  final VoidCallback? onClaritySpeak;
  final VoidCallback? onStopSpeak;
  final VoidCallback? onToggleSettings;
  final void Function(List<String> words, Subtitles sub)? onWordSelected;
  final void Function(double speed)? onSpeedChanged;
  final void Function(double fontSize)? onFontSizeChanged;
  final VoidCallback? onToggleFullscreen;

  /// 弹出面板回调
  final void Function(BuildContext context) _onShowSpeedPicker;
  final void Function(BuildContext context) _onShowFontSizePicker;
  final void Function(BuildContext context) _onShowLoopPicker;

  /// 按钮 GlobalKey（由父页面注入，供面板定位）
  final GlobalKey speedKey;
  final GlobalKey fontSizeKey;
  final GlobalKey loopKey;

  BottomControls({
    super.key,
    required this.isVideo,
    required this.isLandscape,
    required this.state,
    required this.notifier,
    this.hasSubtitles = false,
    this.currentSub,
    this.showFollow = false,
    this.isTtsSpeaking = false,
    this.settingsExpanded = false,
    required this.onToggleFollow,
    this.onClaritySpeak,
    this.onStopSpeak,
    this.onToggleSettings,
    this.onWordSelected,
    this.onSpeedChanged,
    this.onFontSizeChanged,
    this.onToggleFullscreen,
    // 弹出面板回调（由父页面管理 OverlayEntry）
    /// 显示倍速面板
    required void Function(BuildContext context) onShowSpeedPicker,
    /// 显示字号面板
    required void Function(BuildContext context) onShowFontSizePicker,
    /// 显示循环模式面板
    required void Function(BuildContext context) onShowLoopPicker,
    // 按钮 GlobalKey（由父页面注入）
    required this.speedKey,
    required this.fontSizeKey,
    required this.loopKey,
  })  : _onShowSpeedPicker = onShowSpeedPicker,
        _onShowFontSizePicker = onShowFontSizePicker,
        _onShowLoopPicker = onShowLoopPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  // ═══════════════════════════════════════════════════════════
  // 竖屏布局 (Portrait) — 统一黑色容器，填充底部
  // ═══════════════════════════════════════════════════════════

  Widget _buildPortraitLayout(BuildContext context) {
    return Container(
      color: Colors.black, // 纯黑背景，填充整个底部宽度
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom, // 仅处理 Home Indicator 区域
      ),
      child: SafeArea(
        top: false, // 不处理顶部（TopBar 已处理）
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条 + 时间（第一行）
            _buildProgressBarWithTime(context),

            SizedBox(height: adaptive.Adaptive.h(6)),

            // 控制按钮行：左侧核心 + 右侧文字按钮（一行排开，不换行）
            _buildPortraitControlRow(context),
          ],
        ),
      ),
    );
  }

  /// 进度条 + 两端时间显示
  Widget _buildProgressBarWithTime(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
      child: Row(
        children: [
          // 当前时间
          Text(
            UnifiedPlayerLogic.fmtDuration(state.position),
            style: TextStyle(
              color: Colors.white70,
              fontSize: adaptive.Adaptive.sp(11),
            ),
          ),

          SizedBox(width: adaptive.Adaptive.w(8)),

          // 进度条
          Expanded(child: _buildProgressBar(context)),

          SizedBox(width: adaptive.Adaptive.w(8)),

          // 总时长
          Text(
            UnifiedPlayerLogic.fmtDuration(state.duration),
            style: TextStyle(
              color: Colors.white70,
              fontSize: adaptive.Adaptive.sp(11),
            ),
          ),
        ],
      ),
    );
  }

  /// 竖屏控制按钮行（V2.1：参考图3，文字按钮一行排开不换行）
  /// 布局：[左侧核心图标按钮] ... [右侧文字按钮(紧凑)]
  Widget _buildPortraitControlRow(BuildContext context) {
    final btnSize = adaptive.Adaptive.w(40);
    final iconSize = adaptive.Adaptive.icon(20);

    return Row(
      children: [
        // ═══════ 左侧：核心控制图标按钮 ═══════
        // 注意：已移除「字幕显隐」按钮（用户要求不需要）

        // 上一句
        _buildIconButton(
          context: context,
          icon: AppIcons.skipPrevious,
          size: btnSize,
          iconSize: iconSize,
          tooltip: '上一句',
          onTap: () => notifier.previousSentence(),
        ),

        // 播放/暂停（稍大）
        _buildIconButton(
          context: context,
          icon: state.playerState == PlayerState.playing
              ? AppIcons.pause
              : AppIcons.play,
          size: btnSize + 4,
          iconSize: iconSize + 4,
          tooltip: state.playerState == PlayerState.playing ? '暂停' : '播放',
          onTap: () => notifier.togglePlayPause(),
        ),

        // 下一句
        _buildIconButton(
          context: context,
          icon: AppIcons.skipNext,
          size: btnSize,
          iconSize: iconSize,
          tooltip: '下一句',
          onTap: () => notifier.nextSentence(),
        ),

        // ═══════ 右侧：文字按钮（紧凑，一行排开）═══════
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasSubtitles) ...[
                // 翻译
                _buildCompactTextBtn(
                  context,
                  state.translateVisible ? '翻译' : '翻译',
                  () => notifier.toggleTranslateVisible(),
                  isActive: state.translateVisible,
                ),
                SizedBox(width: adaptive.Adaptive.w(4)),

                // 单句暂停
                _buildCompactTextBtn(
                  context,
                  state.singleSentencePause ? '单句暂停' : '单句暂停',
                  () => notifier.toggleSingleSentencePause(),
                  isActive: state.singleSentencePause,
                ),
                SizedBox(width: adaptive.Adaptive.w(4)),

                // 单句循环（从设置面板提取到主行）
                Container(
                  key: loopKey,
                  child: _buildCompactTextBtn(
                    context,
                    _getShortLoopModeLabel(),
                    () => _onShowLoopPicker(context),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(4)),
              ],

              // 倍速
              GestureDetector(
                key: speedKey,
                onTap: () => _onShowSpeedPicker(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.w(6),
                    vertical: adaptive.Adaptive.h(4),
                  ),
                  child: Text(
                    '${state.speed.toStringAsFixed(1)}X',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: adaptive.Adaptive.sp(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              if (hasSubtitles) SizedBox(width: adaptive.Adaptive.w(4)),

              // 字号调整（竖屏常用功能，直接显示在主行）
              GestureDetector(
                key: fontSizeKey,
                onTap: () => _onShowFontSizePicker(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.w(6),
                    vertical: adaptive.Adaptive.h(4),
                  ),
                  child: Text(
                    '字号', // 直接显示数字，如 "18"
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: adaptive.Adaptive.sp(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 获取简短循环模式标签
  String _getShortLoopModeLabel() {
    switch (state.loopingMode) {
      case 'single_loop':
        return '单集循环';
      case 'list_loop':
        return '列表循环';
      case 'single_play':
        return '单集播放';
      case 'sequence_play':
        return '顺序播放';
      default:
        return '循环';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 横屏布局 (Landscape) — 2行：进度条 + 控制按钮
  // ═══════════════════════════════════════════════════════════

  Widget _buildLandscapeLayout(BuildContext context) {
    final btnSize = adaptive.Adaptive.w(36);
    final iconSize = adaptive.Adaptive.icon(18);

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：进度条 + 两端时间
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(12),
                vertical: adaptive.Adaptive.h(2),
              ),
              child: Row(
                children: [
                  Text(
                    UnifiedPlayerLogic.fmtDuration(state.position),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: adaptive.Adaptive.sp(11),
                    ),
                  ),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  Expanded(child: _buildProgressBar(context)),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  Text(
                    UnifiedPlayerLogic.fmtDuration(state.duration),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: adaptive.Adaptive.sp(11),
                    ),
                  ),
                ],
              ),
            ),

            // 第二行：控制按钮（左右对称，参考竖屏按钮组）
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(12),
                vertical: adaptive.Adaptive.h(2),
              ),
              child: Row(
                children: [
                  // 左侧：上一句 / 播放 / 下一句
                  _buildIconButton(
                    context: context,
                    icon: AppIcons.skipPrevious,
                    size: btnSize,
                    iconSize: iconSize,
                    onTap: () => notifier.previousSentence(),
                  ),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  _buildIconButton(
                    context: context,
                    icon: state.playerState == PlayerState.playing
                        ? AppIcons.pause
                        : AppIcons.play,
                    size: btnSize + 4,
                    iconSize: iconSize + 2,
                    onTap: () => notifier.togglePlayPause(),
                  ),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  _buildIconButton(
                    context: context,
                    icon: AppIcons.skipNext,
                    size: btnSize,
                    iconSize: iconSize,
                    onTap: () => notifier.nextSentence(),
                  ),

                  const Spacer(),

                  // 右侧：功能按钮（与竖屏一致的完整按钮组）
                  if (hasSubtitles) ...[
                    _buildCompactTextBtn(
                      context,
                      '翻译',
                      () => notifier.toggleTranslateVisible(),
                      isActive: state.translateVisible,
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    _buildCompactTextBtn(
                      context,
                      '单句停',
                      () => notifier.toggleSingleSentencePause(),
                      isActive: state.singleSentencePause,
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Container(
                      key: loopKey,
                      child: _buildCompactTextBtn(
                        context,
                        _getShortLoopModeLabel(),
                        () => _onShowLoopPicker(context),
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    GestureDetector(
                      key: speedKey,
                      onTap: () => _onShowSpeedPicker(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: adaptive.Adaptive.w(6),
                          vertical: adaptive.Adaptive.h(4),
                        ),
                        child: Text(
                          '${state.speed.toStringAsFixed(1)}X',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: adaptive.Adaptive.sp(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    GestureDetector(
                      key: fontSizeKey,
                      onTap: () => _onShowFontSizePicker(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: adaptive.Adaptive.w(6),
                          vertical: adaptive.Adaptive.h(4),
                        ),
                        child: Text(
                          '字号',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: adaptive.Adaptive.sp(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),

                    // 全屏按钮
                    if (isVideo)
                      _buildIconButton(
                        context: context,
                        icon: AppIcons.fullscreen,
                        size: btnSize,
                        iconSize: iconSize,
                        onTap: () => onToggleFullscreen?.call(),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 通用组件构建方法
  // ═══════════════════════════════════════════════════════════

  /// 进度条
  Widget _buildProgressBar(BuildContext context) {
    final trackHeight = adaptive.isIPad() ? 5.0 : 3.5;
    final thumbRadius = adaptive.isIPad() ? 7.0 : 5.5;

    return SizedBox(
      height: adaptive.Adaptive.h(22), // 触控热区
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: trackHeight,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: thumbRadius + 10,
          ),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: Colors.white24,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.15),
        ),
        child: Slider(
          value: state.duration.inMilliseconds > 0
              ? (state.position.inMilliseconds / state.duration.inMilliseconds)
                    .clamp(0.0, 1.0)
              : 0.0,
          onChanged: (v) {
            final ms = (v * state.duration.inMilliseconds).toInt();
            notifier.seekToMs(ms);
          },
        ),
      ),
    );
  }

  /// 图标按钮（统一样式，无特殊背景）
  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
    String? tooltip,
    bool isActive = false,
  }) {
    final widget = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: isActive
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              )
            : null,
        child: Icon(
          icon,
          color: isActive ? AppColors.primary : Colors.white,
          size: iconSize,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: widget);
    }
    return widget;
  }

  /// 横屏紧凑文字按钮（支持激活状态高亮）
  Widget _buildCompactTextBtn(
    BuildContext context,
    String text,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(6),
          vertical: adaptive.Adaptive.h(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? AppColors.primary : Colors.white70,
            fontSize: adaptive.Adaptive.sp(12),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
