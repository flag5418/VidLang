import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/player/unified/unified_player_logic.dart';

/// 统一底部控制栏
///
/// 布局设计（基于 V1.2 文档）:
/// - 竖屏: 2行结构（统一黑色容器填充整个底部）
///   [进度条(带时间)] [第1行控制按钮] [第2行功能面板]
/// - 横屏: 1行结构
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

  const BottomControls({
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
  });

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

            SizedBox(height: adaptive.Adaptive.h(8)),

            // 第1行：基础控制按钮
            _buildPrimaryControlRow(context),

            // 第2行：功能按钮（设置展开时显示）
            if (settingsExpanded && hasSubtitles) ...[
              SizedBox(height: adaptive.Adaptive.h(8)),
              _buildSettingsPanelRow(context),
            ],
          ],
        ),
      ),
    );
  }

  /// 进度条 + 两端时间显示
  Widget _buildProgressBarWithTime(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
      ),
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

  /// 第1行：基础控制按钮（始终显示）
  Widget _buildPrimaryControlRow(BuildContext context) {
    final btnSize = adaptive.Adaptive.w(44);
    final iconSize = adaptive.Adaptive.icon(22);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 字幕显隐（仅字幕模式）
        if (hasSubtitles)
          _buildIconButton(
            context: context,
            icon: state.subtitleVisible ? AppIcons.visibility : AppIcons.visibilityOff,
            size: btnSize,
            iconSize: iconSize,
            onTap: () => notifier.toggleSubtitleVisible(),
          )
        else
          SizedBox(width: btnSize),

        // 上一句
        _buildIconButton(
          context: context,
          icon: AppIcons.skipPrevious,
          size: btnSize,
          iconSize: iconSize,
          onTap: () => notifier.previousSentence(),
        ),

        // 播放/暂停（统一样式，无特殊背景）
        _buildIconButton(
          context: context,
          icon: state.playerState == PlayerState.playing ? AppIcons.pause : AppIcons.play,
          size: btnSize,
          iconSize: adaptive.Adaptive.icon(26), // 稍大一点
          onTap: () => notifier.togglePlayPause(),
        ),

        // 下一句
        _buildIconButton(
          context: context,
          icon: AppIcons.skipNext,
          size: btnSize,
          iconSize: iconSize,
          onTap: () => notifier.nextSentence(),
        ),

        // 设置按钮或倍速（无字幕时显示倍速入口）
        if (hasSubtitles && onToggleSettings != null)
          _buildIconButton(
            context: context,
            icon: AppIcons.settings,
            size: btnSize,
            iconSize: iconSize,
            isActive: settingsExpanded,
            onTap: onToggleSettings!,
          )
        else if (!hasSubtitles)
          _buildTextButton(context, '${state.speed.toStringAsFixed(1)}X', () => _showSpeedPicker(context))
        else
          SizedBox(width: btnSize),
      ],
    );
  }

  /// 第2行：设置面板（点击⚙️展开，仅字幕模式）
  Widget _buildSettingsPanelRow(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: adaptive.Adaptive.w(8),
        runSpacing: adaptive.Adaptive.h(8),
        children: [
          _buildToggleButton(context, '跟读', showFollow, AppColors.primary, onToggleFollow),
          _buildToggleButton(context, '停止', isTtsSpeaking, Colors.orangeAccent, onStopSpeak ?? () {}),
          _buildToggleButton(context, '由慢→快', state.slowToFastActive, AppColors.primary,
              () => notifier.toggleSlowToFastCurrentSentence()),
          _buildToggleButton(context, '翻译', state.translateVisible, AppColors.primary,
              () => notifier.toggleTranslateVisible()),
          _buildTextButton(context, '${state.speed.toStringAsFixed(1)}X', () => _showSpeedPicker(context)),
          _buildTextButton(context, _getLoopModeLabel(), () => _showLoopModePicker(context)),
          _buildToggleButton(context, '单句停', state.singleSentencePause, AppColors.primary,
              () => notifier.toggleSingleSentencePause()),
          _buildTextButton(context, '字号', () => _showFontSizePicker(context)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 横屏布局 (Landscape)
  // ═══════════════════════════════════════════════════════════

  Widget _buildLandscapeLayout(BuildContext context) {
    final btnSize = adaptive.Adaptive.w(40);
    final iconSize = adaptive.Adaptive.icon(20);

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.Adaptive.w(12),
            vertical: adaptive.Adaptive.h(6),
          ),
          child: Row(
            children: [
              _buildIconButton(context: context, icon: AppIcons.skipPrevious, size: btnSize, iconSize: iconSize,
                  onTap: () => notifier.previousSentence()),
              // 播放/暂停（统一样式）
              _buildIconButton(context: context,
                  icon: state.playerState == PlayerState.playing ? AppIcons.pause : AppIcons.play,
                  size: btnSize + 8, iconSize: iconSize + 2,
                  onTap: () => notifier.togglePlayPause()),
              _buildIconButton(context: context, icon: AppIcons.skipNext, size: btnSize, iconSize: iconSize,
                  onTap: () => notifier.nextSentence()),

              SizedBox(width: adaptive.Adaptive.w(12)),

              // 时间
              Text(
                '${UnifiedPlayerLogic.fmtDuration(state.position)} / ${UnifiedPlayerLogic.fmtDuration(state.duration)}',
                style: TextStyle(color: Colors.white70, fontSize: adaptive.Adaptive.sp(11)),
              ),

              SizedBox(width: adaptive.Adaptive.w(12)),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasSubtitles) ...[
                      _buildCompactTextBtn(context, '翻译', () => notifier.toggleTranslateVisible()),
                      SizedBox(width: adaptive.Adaptive.w(6)),
                      _buildCompactTextBtn(context, '单句停', () => notifier.toggleSingleSentencePause()),
                      SizedBox(width: adaptive.Adaptive.w(6)),
                    ],

                    // 倍速（始终显示）
                    GestureDetector(
                      onTap: () => _showSpeedPicker(context),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: adaptive.Adaptive.w(6),
                          vertical: adaptive.Adaptive.h(4),
                        ),
                        child: Text('${state.speed.toStringAsFixed(1)}X',
                            style: TextStyle(color: Colors.white, fontSize: adaptive.Adaptive.sp(12))),
                      ),
                    ),

                    if (hasSubtitles)
                      SizedBox(width: adaptive.Adaptive.w(8)),

                    // 全屏切换
                    _buildIconButton(context: context, icon: AppIcons.fullscreen, size: btnSize, iconSize: iconSize,
                        onTap: onToggleFullscreen ?? () {}),
                  ],
                ),
              ),
            ],
          ),
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
          overlayShape: RoundSliderOverlayShape(overlayRadius: thumbRadius + 10),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: Colors.white24,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.15),
        ),
        child: Slider(
          value: state.duration.inMilliseconds > 0
              ? (state.position.inMilliseconds / state.duration.inMilliseconds).clamp(0.0, 1.0)
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
        child: Icon(icon, color: isActive ? AppColors.primary : Colors.white, size: iconSize),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: widget);
    }
    return widget;
  }

  /// Toggle 文字按钮
  Widget _buildToggleButton(BuildContext context, String text, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(12),
          vertical: adaptive.Adaptive.h(6),
        ),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        ),
        child: Text(text,
            style: TextStyle(
              color: active ? color : Colors.white70,
              fontSize: adaptive.Adaptive.sp(13),
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    );
  }

  /// 文字按钮
  Widget _buildTextButton(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(10), vertical: adaptive.Adaptive.h(6)),
        child: Text(text,
            style: TextStyle(color: Colors.white, fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.w500)),
      ),
    );
  }

  /// 横屏紧凑文字按钮
  Widget _buildCompactTextBtn(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(6), vertical: adaptive.Adaptive.h(4)),
        child: Text(text, style: TextStyle(color: Colors.white70, fontSize: adaptive.Adaptive.sp(12))),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗选择器
  // ═══════════════════════════════════════════════════════════

  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    TDActionSheet.showListActionSheet(
      context,
      items: speeds.map((s) {
        final label = s == 1.0 ? '${s}X (正常)' : '${s.toStringAsFixed(2)}X';
        return TDActionSheetItem(label: label);
      }).toList(),
      onSelected: (item, index) {
        notifier.setSpeed(speeds[index]);
        onSpeedChanged?.call(speeds[index]);
      },
    );
  }

  String _getLoopModeLabel() {
    switch (state.loopingMode) {
      case 'single_loop': return '单集循环';
      case 'list_loop': return '列表循环';
      case 'single_play': return '单集播放';
      case 'sequence_play': return '顺序播放';
      default: return '循环模式';
    }
  }

  void _showLoopModePicker(BuildContext context) {
    const modes = ['single_loop', 'list_loop', 'single_play', 'sequence_play'];
    const labels = ['单集循环', '列表循环', '单集播放', '顺序播放'];

    TDActionSheet.showListActionSheet(
      context,
      items: List.generate(modes.length, (i) => TDActionSheetItem(label: labels[i])),
      onSelected: (item, index) => notifier.setLoopingMode(modes[index]),
    );
  }

  void _showFontSizePicker(BuildContext context) {
    double tempValue = state.subtitleFontSize;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E302A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('字号大小', style: TextStyle(color: Colors.white, fontSize: adaptive.Adaptive.sp(16))),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${tempValue.toInt()}',
                  style: TextStyle(color: AppColors.primary, fontSize: adaptive.Adaptive.sp(32), fontWeight: FontWeight.bold)),
              SizedBox(height: adaptive.Adaptive.h(16)),
              Slider(
                value: tempValue.clamp(12.0, 40.0),
                min: 12,
                max: 40,
                divisions: 28,
                onChanged: (v) => setDialogState(() => tempValue = v),
                onChangeEnd: (v) { notifier.setSubtitleFontSize(v); onFontSizeChanged?.call(v); },
                activeColor: AppColors.primary,
                inactiveColor: Colors.white24,
                thumbColor: AppColors.primary,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('小', style: TextStyle(color: Colors.white54)), Text('大', style: TextStyle(color: Colors.white54))]),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('确定', style: TextStyle(color: AppColors.primary)))],
      ),
    );
  }
}
