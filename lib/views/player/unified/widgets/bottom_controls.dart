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
/// - 竖屏: 2行结构
///   第1行(始终): [👁字幕] [|◀上] [▶/⏸播] [▶|下] [⚙️设置]
///   第2行(⚙️展开,仅字幕): [跟读][清晰朗读][由慢→快][翻译][倍速▾][单句循环][单句暂停][字号]
/// - 横屏: 1行结构
///   [|◀] [▶] [▶|] 时间 [翻译][单句停][倍速▾] [⊞全屏]
class BottomControls extends ConsumerWidget {
  final bool isVideo;
  final bool isLandscape;
  final PlayerEngineState state;
  final PlayerEngineNotifier notifier;
  final bool hasSubtitles;
  final Subtitles? currentSub;
  final bool showFollow;
  final bool isTtsSpeaking;
  final bool settingsExpanded; // 设置面板是否展开
  final VoidCallback onToggleFollow;
  final VoidCallback? onClaritySpeak;
  final VoidCallback? onStopSpeak;
  final VoidCallback? onToggleSettings; // 切换设置面板
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
  // 竖屏布局 (Portrait)
  // ═══════════════════════════════════════════════════════════

  Widget _buildPortraitLayout(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 16),
          vertical: adaptive.Adaptive.h(context, 8),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.black.withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            _buildProgressBar(context),

            SizedBox(height: adaptive.Adaptive.h(context, 10)),

            // 第1行：基础控制按钮（始终显示）
            _buildPrimaryControlRow(context),

            // 第2行：功能按钮（设置展开时显示，仅字幕模式）
            if (settingsExpanded && hasSubtitles) ...[
              SizedBox(height: adaptive.Adaptive.h(context, 8)),
              _buildSettingsPanelRow(context),
            ],
          ],
        ),
      ),
    );
  }

  /// 第1行：基础控制按钮
  Widget _buildPrimaryControlRow(BuildContext context) {
    final btnSize = adaptive.Adaptive.w(context, 44);
    final playBtnSize = adaptive.Adaptive.w(context, 56);
    final iconSize = adaptive.Adaptive.icon(context, 22);

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
            tooltip: state.subtitleVisible ? '隐藏字幕' : '显示字幕',
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
          tooltip: '上一句',
        ),

        // 播放/暂停（大按钮）
        _buildPlayButton(context, playBtnSize),

        // 下一句
        _buildIconButton(
          context: context,
          icon: AppIcons.skipNext,
          size: btnSize,
          iconSize: iconSize,
          onTap: () => notifier.nextSentence(),
          tooltip: '下一句',
        ),

        // 设置按钮（仅字幕模式有设置面板可展开）
        if (hasSubtitles && onToggleSettings != null)
          _buildIconButton(
            context: context,
            icon: AppIcons.settings,
            size: btnSize,
            iconSize: iconSize,
            onTap: onToggleSettings!,
            tooltip: settingsExpanded ? '收起设置' : '更多设置',
            isActive: settingsExpanded,
          )
        else if (!hasSubtitles)
          // 无字幕时仍显示倍速入口
          _buildTextButton(
            context: context,
            text: '${state.speed.toStringAsFixed(1)}X',
            onTap: () => _showSpeedPicker(context),
          )
        else
          SizedBox(width: btnSize),
      ],
    );
  }

  /// 第2行：设置面板（点击⚙️展开）
  Widget _buildSettingsPanelRow(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: adaptive.Adaptive.w(context, 8),
        runSpacing: adaptive.Adaptive.h(context, 8),
        children: [
          // 跟读
          _buildToggleButton(
            context: context,
            text: '跟读',
            active: showFollow,
            activeColor: AppColors.primary,
            onTap: onToggleFollow,
          ),

          // 清晰朗读
          _buildToggleButton(
            context: context,
            text: isTtsSpeaking ? '停止' : '朗读',
            active: isTtsSpeaking,
            activeColor: Colors.orangeAccent,
            onTap: isTtsSpeaking ? (onStopSpeak ?? () {}) : (onClaritySpeak ?? () {}),
          ),

          // 由慢到快
          _buildToggleButton(
            context: context,
            text: '由慢→快',
            active: state.slowToFastActive,
            activeColor: AppColors.primary,
            onTap: () => notifier.toggleSlowToFastCurrentSentence(),
          ),

          // 翻译开关
          _buildToggleButton(
            context: context,
            text: '翻译',
            active: state.translateVisible,
            activeColor: AppColors.primary,
            onTap: () => notifier.toggleTranslateVisible(),
          ),

          // 倍速
          _buildTextButton(
            context: context,
            text: '${state.speed.toStringAsFixed(1)}X',
            onTap: () => _showSpeedPicker(context),
          ),

          // 循环模式（通过状态文字显示当前模式）
          _buildTextButton(
            context: context,
            text: _getLoopModeLabel(),
            onTap: () => _showLoopModePicker(context),
          ),

          // 单句暂停
          _buildToggleButton(
            context: context,
            text: '单句暂停',
            active: state.singleSentencePause,
            activeColor: AppColors.primary,
            onTap: () => notifier.toggleSingleSentencePause(),
          ),

          // 字号
          _buildTextButton(
            context: context,
            text: '字号',
            onTap: () => _showFontSizePicker(context),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 横屏布局 (Landscape)
  // ═══════════════════════════════════════════════════════════

  Widget _buildLandscapeLayout(BuildContext context) {
    final btnSize = adaptive.Adaptive.w(context, 40);
    final iconSize = adaptive.Adaptive.icon(context, 20);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 12),
          vertical: adaptive.Adaptive.h(context, 6),
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
        ),
        child: Row(
          children: [
            // 左侧：播放控制
            _buildIconButton(
              context: context,
              icon: AppIcons.skipPrevious,
              size: btnSize,
              iconSize: iconSize,
              onTap: () => notifier.previousSentence(),
            ),
            _buildPlayButton(context, btnSize + 8),
            _buildIconButton(
              context: context,
              icon: AppIcons.skipNext,
              size: btnSize,
              iconSize: iconSize,
              onTap: () => notifier.nextSentence(),
            ),

            SizedBox(width: adaptive.Adaptive.w(context, 12)),

            // 时间
            Text(
              '${UnifiedPlayerLogic.fmtDuration(state.position)} / ${UnifiedPlayerLogic.fmtDuration(state.duration)}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: adaptive.Adaptive.sp(context, 11),
              ),
            ),

            SizedBox(width: adaptive.Adaptive.w(context, 12)),

            // 右侧：功能按钮（仅字幕时显示部分）
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasSubtitles) ...[
                    _buildCompactTextBtn(context, '翻译', () => notifier.toggleTranslateVisible()),
                    SizedBox(width: adaptive.Adaptive.w(context, 8)),
                    _buildCompactTextBtn(context, '单句停', () => notifier.toggleSingleSentencePause()),
                    SizedBox(width: adaptive.Adaptive.w(context, 8)),
                  ],

                  // 倍速（始终显示）
                  GestureDetector(
                    onTap: () => _showSpeedPicker(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(context, 8),
                        vertical: adaptive.Adaptive.h(context, 4),
                      ),
                      child: Text(
                        '${state.speed.toStringAsFixed(1)}X',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: adaptive.Adaptive.sp(context, 12),
                        ),
                      ),
                    ),
                  ),

                  if (hasSubtitles) ...[
                    SizedBox(width: adaptive.Adaptive.w(context, 8)),
                  ],

                  // 全屏切换
                  _buildIconButton(
                    context: context,
              icon: AppIcons.fullscreen,
                    size: btnSize,
                    iconSize: iconSize,
                    onTap: onToggleFullscreen ?? () {},
                  ),
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
    final trackHeight = adaptive.isIPad(context) ? 6.0 : 4.0;
    final thumbRadius = adaptive.isIPad(context) ? 7.0 : 5.5;

    return SizedBox(
      height: adaptive.Adaptive.h(context, 20), // 热区高度
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: trackHeight,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
          overlayShape: RoundSliderOverlayShape(overlayRadius: thumbRadius + 8),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: Colors.white24,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.2),
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

  /// 播放/暂停大按钮
  Widget _buildPlayButton(BuildContext context, double size) {
    final isPlaying = state.playerState == PlayerState.playing;
    final iconSize = size * 0.5;

    return GestureDetector(
      onTap: () => notifier.togglePlayPause(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.15),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Icon(
          isPlaying ? AppIcons.pause : AppIcons.play,
          color: AppColors.primary,
          size: iconSize,
        ),
      ),
    );
  }

  /// 图标按钮（圆形触控区）
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
                color: AppColors.primary.withValues(alpha: 0.2),
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

  /// Toggle 文字按钮（跟读、朗读等）
  Widget _buildToggleButton({
    required BuildContext context,
    required String text,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 12),
          vertical: adaptive.Adaptive.h(context, 6),
        ),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
          border: active
              ? Border.all(color: activeColor.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? activeColor : Colors.white70,
            fontSize: adaptive.Adaptive.sp(context, 13),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 文字按钮（倍速、字号等触发弹窗）
  Widget _buildTextButton({
    required BuildContext context,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 10),
          vertical: adaptive.Adaptive.h(context, 6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: adaptive.Adaptive.sp(context, 13),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 横屏紧凑文字按钮
  Widget _buildCompactTextBtn(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 6),
          vertical: adaptive.Adaptive.h(context, 4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white70,
            fontSize: adaptive.Adaptive.sp(context, 12),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 弹窗选择器（使用 TDesign 组件）
  // ═══════════════════════════════════════════════════════════

  /// 倍速选择器
  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    TDActionSheet.showListActionSheet(
      context,
      items: speeds.map((s) {
        final label = s == 1.0 ? '${s}X (正常)' : '${s.toStringAsFixed(2)}X';
        return TDActionSheetItem(label: label);
      }).toList(),
      onSelected: (item, index) {
        final selected = speeds[index];
        notifier.setSpeed(selected);
        onSpeedChanged?.call(selected);
      },
    );
  }

  /// 循环模式标签
  String _getLoopModeLabel() {
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
        return '循环模式';
    }
  }

  /// 循环模式选择器
  void _showLoopModePicker(BuildContext context) {
    const modes = ['single_loop', 'list_loop', 'single_play', 'sequence_play'];
    const labels = ['单集循环', '列表循环', '单集播放', '顺序播放'];

    TDActionSheet.showListActionSheet(
      context,
      items: List.generate(modes.length, (i) => TDActionSheetItem(label: labels[i])),
      onSelected: (item, index) {
        notifier.setLoopingMode(modes[index]);
      },
    );
  }

  /// 字号选择器
  void _showFontSizePicker(BuildContext context) {
    double tempValue = state.subtitleFontSize;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E302A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('字号大小', style: TextStyle(color: Colors.white, fontSize: adaptive.Adaptive.sp(context, 16))),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tempValue.toInt()}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: adaptive.Adaptive.sp(context, 32),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(context, 16)),
              Slider(
                value: tempValue,
                min: 12,
                max: 40,
                divisions: 28,
                onChanged: (v) {
                  setDialogState(() => tempValue = v);
                },
                onChangeEnd: (v) {
                  notifier.setSubtitleFontSize(v);
                  onFontSizeChanged?.call(v);
                },
                activeColor: AppColors.primary,
                inactiveColor: Colors.white24,
                thumbColor: AppColors.primary,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('小', style: TextStyle(color: Colors.white54, fontSize: adaptive.Adaptive.sp(context, 12))),
                  Text('大', style: TextStyle(color: Colors.white54, fontSize: adaptive.Adaptive.sp(context, 12))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
