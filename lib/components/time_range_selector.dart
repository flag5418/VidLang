/// 通用时间筛选组件
///
/// 提供统一的时间范围选择功能，支持：
/// - 预设选项：近7天、当月、近90天、今年、全部
/// - 自定义日期范围选择
/// - 统一的对话框样式
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 时间范围选项
class TimeRangeOption {
  final String value;
  final String label;

  const TimeRangeOption({required this.value, required this.label});
}

/// 默认时间范围选项
const List<TimeRangeOption> kDefaultTimeRangeOptions = [
  TimeRangeOption(value: '7d', label: '近7天'),
  TimeRangeOption(value: '30d', label: '当月'),
  TimeRangeOption(value: '90d', label: '近90天'),
  TimeRangeOption(value: 'year', label: '今年'),
  TimeRangeOption(value: 'all', label: '全部'),
];

/// 时间范围选择回调
typedef TimeRangeSelectedCallback = void Function(String value);

/// 显示时间范围选择对话框
///
/// [context] BuildContext
/// [currentValue] 当前选中的值
/// [onSelected] 选择回调
/// [options] 可选的自定义选项列表，默认使用 kDefaultTimeRangeOptions
void showTimeRangePicker({
  required BuildContext context,
  required String currentValue,
  required TimeRangeSelectedCallback onSelected,
  List<TimeRangeOption>? options,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'TimeRangePicker',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => _TimeRangePickerDialog(
      currentValue: currentValue,
      options: options ?? kDefaultTimeRangeOptions,
      onSelected: (value) {
        Navigator.of(context).pop();
        onSelected(value);
      },
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// 时间范围选择按钮
///
/// 显示当前选中的时间范围，点击弹出选择对话框
class TimeRangeSelector extends StatelessWidget {
  final String currentValue;
  final TimeRangeSelectedCallback onSelected;
  final List<TimeRangeOption>? options;

  const TimeRangeSelector({
    super.key,
    required this.currentValue,
    required this.onSelected,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final opts = options ?? kDefaultTimeRangeOptions;
    final currentLabel = opts
        .firstWhere((o) => o.value == currentValue, orElse: () => opts.first)
        .label;

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => showTimeRangePicker(
          context: context,
          currentValue: currentValue,
          onSelected: onSelected,
          options: opts,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.Adaptive.w(10),
            vertical: adaptive.Adaptive.h(4),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
            color: colorScheme.primary.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLabel,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(4)),
              Icon(
                AppIcons.expandMore,
                size: adaptive.Adaptive.sp(14),
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 时间范围选择对话框
class _TimeRangePickerDialog extends StatefulWidget {
  final String currentValue;
  final List<TimeRangeOption> options;
  final ValueChanged<String> onSelected;

  const _TimeRangePickerDialog({
    required this.currentValue,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_TimeRangePickerDialog> createState() => _TimeRangePickerDialogState();
}

class _TimeRangePickerDialogState extends State<_TimeRangePickerDialog> {
  late String _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIpad = adaptive.isIPad();

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isIpad
              ? adaptive.Adaptive.w(80)
              : adaptive.Adaptive.w(32),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(isIpad ? 16 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: adaptive.Adaptive.w(32),
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 标题区 ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    adaptive.Adaptive.w(24),
                    adaptive.Adaptive.h(24),
                    adaptive.Adaptive.w(24),
                    adaptive.Adaptive.h(8),
                  ),
                  child: Text(
                    '选择时间段',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(17),
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),

                // ── 选项区 ──
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.w(20),
                  ),
                  child: Column(
                    children: widget.options.map((option) {
                      final isSelected = option.value == _selectedValue;

                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedValue = option.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                            bottom: adaptive.Adaptive.h(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: adaptive.Adaptive.w(16),
                            vertical: adaptive.Adaptive.h(14),
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.1)
                                : cs.surfaceContainerHighest.withValues(
                                    alpha: 0.3,
                                  ),
                            border: Border.all(
                              color: isSelected
                                  ? cs.primary
                                  : cs.outlineVariant.withValues(alpha: 0.5),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(
                              adaptive.Adaptive.r(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: adaptive.Adaptive.sp(15),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? cs.primary
                                        : cs.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: adaptive.Adaptive.w(22),
                                  height: adaptive.Adaptive.w(22),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: adaptive.Adaptive.sp(14),
                                    color: cs.onPrimary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ── 按钮区 ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    adaptive.Adaptive.w(20),
                    adaptive.Adaptive.h(20),
                    adaptive.Adaptive.w(20),
                    adaptive.Adaptive.h(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TDButton(
                          text: '取消',
                          size: TDButtonSize.large,
                          type: TDButtonType.outline,
                          shape: TDButtonShape.round,
                          height: adaptive.Adaptive.h(48),
                          style: TDButtonStyle(
                            backgroundColor: Colors.transparent,
                            textColor: AppColors.primary,
                            frameColor: AppColors.primary,
                          ),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: adaptive.Adaptive.w(12)),
                      Expanded(
                        child: TDButton(
                          text: '确定',
                          size: TDButtonSize.large,
                          type: TDButtonType.fill,
                          theme: TDButtonTheme.primary,
                          shape: TDButtonShape.round,
                          height: adaptive.Adaptive.h(48),
                          style: TDButtonStyle(
                            backgroundColor: AppColors.primary,
                            textColor: AppColors.onPrimary,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelected(_selectedValue);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
