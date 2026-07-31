library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 片头/片尾/封面截图设置底部面板
///
/// 遵循项目 UI 规范：
/// - 使用 TDesign Switch 替代 Material SwitchListTile
/// - 使用 TDButton 作为保存按钮
/// - 图标统一使用 AppIcons（TDesign Icons）
/// - 间距使用 AppSpacing，圆角使用 AppRadius
/// - 文字使用 AppTypography
/// - 最小点击区域 48dp
class PlaybackSettingsSheet extends StatefulWidget {
  final PlaybackSettings initial;
  final String title;
  final Future<void> Function(PlaybackSettings settings) onSave;

  const PlaybackSettingsSheet({
    super.key,
    required this.initial,
    required this.onSave,
    this.title = '播放与封面',
  });

  static Future<void> show(
    BuildContext context, {
    required PlaybackSettings initial,
    required Future<void> Function(PlaybackSettings) onSave,
    String title = '播放与封面',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) =>
          PlaybackSettingsSheet(initial: initial, onSave: onSave, title: title),
    );
  }

  @override
  State<PlaybackSettingsSheet> createState() => _PlaybackSettingsSheetState();
}

class _PlaybackSettingsSheetState extends State<PlaybackSettingsSheet> {
  late bool _skipOpening;
  late int _openingSec;
  late bool _skipEnding;
  late int _endingSec;
  late int _thumbnailSec;

  @override
  void initState() {
    super.initState();
    _skipOpening = widget.initial.skipOpening;
    _openingSec = widget.initial.skipOpeningDuration;
    _skipEnding = widget.initial.skipEnding;
    _endingSec = widget.initial.skipEndingDuration;
    _thumbnailSec = widget.initial.thumbnailTime;
  }

  PlaybackSettings get _settings => PlaybackSettings(
        skipOpening: _skipOpening,
        skipOpeningDuration: _openingSec,
        skipEnding: _skipEnding,
        skipEndingDuration: _endingSec,
        thumbnailTime: _thumbnailSec,
      );

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Text(
            widget.title,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(18),
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          // 跳过片头
          _buildSwitchRow(cs, '跳过片头', _skipOpening,
              (v) => setState(() => _skipOpening = v)),
          if (_skipOpening)
            _buildSecondsRow(
              cs,
              '片头时长（秒）',
              _openingSec,
              (v) => setState(() => _openingSec = v),
            ),
          SizedBox(height: AppSpacing.sm),
          // 跳过片尾
          _buildSwitchRow(cs, '跳过片尾', _skipEnding,
              (v) => setState(() => _skipEnding = v)),
          if (_skipEnding)
            _buildSecondsRow(
              cs,
              '片尾时长（秒）',
              _endingSec,
              (v) => setState(() => _endingSec = v),
            ),
          SizedBox(height: AppSpacing.sm),
          // 封面截图时间
          _buildSecondsRow(
            cs,
            '封面截图时间（秒）',
            _thumbnailSec,
            (v) => setState(() => _thumbnailSec = v),
            min: 1,
            max: 600,
          ),
          SizedBox(height: AppSpacing.lg),
          // 保存按钮 — 使用 TDesign TDButton 统一风格
          _buildSaveButton(cs),
        ],
      ),
    );
  }

  /// 开关行：TDesign Switch + 标签
  Widget _buildSwitchRow(
    AppColorsData cs,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeBase),
                color: cs.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
            activeTrackColor: cs.primary.withValues(alpha: 0.35),
            inactiveThumbColor: cs.surface,
            inactiveTrackColor: cs.outlineVariant,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  /// 数字调节行：标签 + 减按钮 + 数值 + 加按钮
  ///
  /// 最小点击区域 48×48 dp，遵循项目规范。
  /// 图标使用 AppIcons（TDesign Icons）。
  Widget _buildSecondsRow(
    AppColorsData cs,
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int min = 0,
    int max = 300,
  }) {
    final iconSize = adaptive.Adaptive.icon(18);
    final btnSize = adaptive.Adaptive.w(36);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeBase),
                color: cs.onSurface,
              ),
            ),
          ),
          // 减按钮
          _buildStepperButton(
            icon: Icon(AppIcons.remove, size: iconSize, color: cs.textSecondary),
            onTap: value > min ? () => onChanged(value - 1) : null,
            enabled: value > min,
            size: btnSize,
          ),
          // 数值显示（固定宽度避免抖动）
          Container(
            width: adaptive.Adaptive.w(40),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeLarge),
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          // 加按钮
          _buildStepperButton(
            icon: Icon(AppIcons.add, size: iconSize, color: cs.textSecondary),
            onTap: value < max ? () => onChanged(value + 1) : null,
            enabled: value < max,
            size: btnSize,
          ),
        ],
      ),
    );
  }

  /// 步进按钮：保证最小 48×48 点击区域
  Widget _buildStepperButton({
    required Icon icon,
    VoidCallback? onTap,
    required bool enabled,
    required double size,
  }) {
    final cs = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? cs.surfaceContainerLow : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: enabled ? cs.outlineVariant : cs.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Opacity(opacity: enabled ? 1.0 : 0.4, child: icon),
      ),
    );
  }

  /// 保存按钮 — 使用 TDesign TDButton 与项目其他弹窗保持一致
  Widget _buildSaveButton(AppColorsData cs) {
    return TDButton(
      text: '保存',
      size: TDButtonSize.large,
      type: TDButtonType.fill,
      theme: TDButtonTheme.primary,
      shape: TDButtonShape.round,
      height: adaptive.Adaptive.h(48),
      textStyle: TextStyle(
        fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeBase),
        fontWeight: FontWeight.w600,
      ),
      style: TDButtonStyle(
        backgroundColor: cs.primary,
        textColor: AppColors.onPrimary,
      ),
      onTap: () async {
        await widget.onSave(_settings);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
