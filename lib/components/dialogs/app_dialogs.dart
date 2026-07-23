/// TDesign 风格统一弹出组件
///
/// 所有弹窗使用 AppBaseDialog 统一样式，确保视觉一致性。
library;

import 'package:flutter/material.dart';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_typography.dart';


// ═══════════════════════════════════════════════════════════════
// 统一弹窗基座
// ═══════════════════════════════════════════════════════════════

class AppBaseDialog extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final double? width;

  const AppBaseDialog({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final isIpad = context.ipad;
    final screenWidth = MediaQuery.of(context).size.width;

    // 弹窗尺寸策略：
    // - iPad: 固定宽度 450，居中显示，不随屏幕缩放
    // - iPhone: 屏幕宽度的 85%，限制在 300-400 之间
    final dialogWidth = isIpad
        ? 450.0
        : (screenWidth * 0.85).clamp(300.0, 400.0);
    final horizontalPadding = (screenWidth - dialogWidth) / 2;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: width ?? dialogWidth,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(isIpad ? 16 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 标题 ──
                if (title != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      adaptive.Adaptive.w(24),
                      adaptive.Adaptive.h(24),
                      adaptive.Adaptive.w(24),
                      adaptive.Adaptive.h(16),
                    ),
                    child: Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(17),
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                // ── 内容 ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    adaptive.Adaptive.w(24),
                    0,
                    adaptive.Adaptive.w(24),
                    0,
                  ),
                  child: child,
                ),
                // ── 按钮栏 ──
                if (actions != null && actions!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      adaptive.Adaptive.w(24),
                      adaptive.Adaptive.h(24),
                      adaptive.Adaptive.w(24),
                      adaptive.Adaptive.h(20),
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < actions!.length; i++) ...[
                          if (i > 0) SizedBox(width: adaptive.Adaptive.w(12)),
                          Expanded(child: actions![i]),
                        ],
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

  /// 构建统一的取消按钮
  static Widget cancelButton(
    BuildContext context, {
    required String text,
    VoidCallback? onTap,
  }) {
    final cs = context.colors;
    return TDButton(
      text: text,
      size: TDButtonSize.large,
      type: TDButtonType.fill,
      shape: TDButtonShape.round,
      height: adaptive.Adaptive.h(48),
      textStyle: TextStyle(
        fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeBase),
        fontWeight: FontWeight.w500,
      ),
      style: TDButtonStyle(
        backgroundColor: cs.surfaceContainerHighest,
        textColor: cs.onSurfaceVariant,
        frameColor: Colors.transparent,
      ),
      onTap: onTap,
    );
  }

  /// 构建统一的确认按钮
  static Widget confirmButton(
    BuildContext context, {
    required String text,
    TDButtonTheme theme = TDButtonTheme.primary,
    VoidCallback? onTap,
  }) {
    final bgColor = theme == TDButtonTheme.danger
        ? AppColors.error
        : AppColors.primary;
    return TDButton(
      text: text,
      size: TDButtonSize.large,
      type: TDButtonType.fill,
      theme: theme,
      shape: TDButtonShape.round,
      height: adaptive.Adaptive.h(48),
      textStyle: TextStyle(
        fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeBase),
        fontWeight: FontWeight.w600,
      ),
      style: TDButtonStyle(
        backgroundColor: bgColor,
        textColor: AppColors.onPrimary,
      ),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 确认对话框（双按钮）— 基于 TDAlertDialog
// ═══════════════════════════════════════════════════════════════

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Widget? contentWidget;
  final bool destructive;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.onConfirm,
    this.onCancel,
    this.contentWidget,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    // 统一使用 AppBaseDialog：宽度通过 Adaptive 自动适配 iPad/iPhone
    // 不再使用 TDAlertDialog（其内部 TDDialogScaffold 固定宽度逻辑导致按钮文字截断）
    return AppBaseDialog(
      title: title,
      actions: [
        AppBaseDialog.cancelButton(
          context,
          text: cancelText,
          onTap: () {
            onCancel?.call();
            Navigator.of(context).pop(false);
          },
        ),
        AppBaseDialog.confirmButton(
          context,
          text: confirmText,
          theme: destructive ? TDButtonTheme.danger : TDButtonTheme.primary,
          onTap: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
        ),
      ],
      child: contentWidget ??
          Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(15),
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    Widget? contentWidget,
    bool destructive = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'AppConfirmDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => AppConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        contentWidget: contentWidget,
        destructive: destructive,
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 提示对话框（单按钮）— 基于 TDConfirmDialog
// ═══════════════════════════════════════════════════════════════

class AppAlertDialog extends StatelessWidget {
  final String? title;
  final String content;
  final String buttonText;
  final VoidCallback? onAction;

  const AppAlertDialog({
    super.key,
    this.title,
    required this.content,
    this.buttonText = '知道了',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return TDConfirmDialog(
      title: title,
      content: null,
      contentWidget: Text(
        content,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(15),
          color: cs.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      buttonText: buttonText,
      buttonStyleCustom: TDButtonStyle(
        backgroundColor: cs.primary,
        textColor: AppColors.onPrimary,
      ),
      action: () {
        Navigator.of(context).pop();
        onAction?.call();
      },
      radius: adaptive.Adaptive.r(14),
    );
  }

  static Future<void> show(
    BuildContext context, {
    String? title,
    required String content,
    String buttonText = '知道了',
    VoidCallback? onAction,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'AppAlertDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => AppAlertDialog(
        title: title,
        content: content,
        buttonText: buttonText,
        onAction: onAction,
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 输入对话框（基于 AppBaseDialog）
// ═══════════════════════════════════════════════════════════════

class AppInputDialog {
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String hintText = '',
    String initialValue = '',
    String confirmText = '确定',
    String cancelText = '取消',
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onSubmit,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? result;
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final cs = Theme.of(ctx).colorScheme;
          return AppBaseDialog(
            title: title,
            actions: [
              AppBaseDialog.cancelButton(
                ctx,
                text: cancelText,
                onTap: () => Navigator.of(ctx).pop(false),
              ),
              AppBaseDialog.confirmButton(
                ctx,
                text: confirmText,
                onTap: () {
                  final val = controller.text.trim();
                  if (validator != null) {
                    final e = validator(val);
                    if (e != null) {
                      setState(() => error = e);
                      return;
                    }
                  }
                  if (val.isEmpty) {
                    setState(() => error = '内容不能为空');
                    return;
                  }
                  result = val;
                  onSubmit?.call(val);
                  Navigator.of(ctx).pop(true);
                },
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp( 15),
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: adaptive.Adaptive.sp( 15),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w( 16),
                      vertical: adaptive.Adaptive.h( 14),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
                      borderSide: BorderSide(color: cs.error, width: 1),
                    ),
                  ),
                ),
                if (error != null) ...[
                  SizedBox(height: adaptive.Adaptive.h( 8)),
                  Text(
                    error!,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp( 12),
                      color: cs.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return confirmed == true ? result : null;
  }
}

// ═══════════════════════════════════════════════════════════════
// 高级选择对话框（卡片式选项风格，类似设备类型弹窗）
// ═══════════════════════════════════════════════════════════════

/// 选择弹窗的数据项
class AppSelectionItem<T> {
  final T value;
  final IconData icon;
  final String title;
  final String? subtitle;

  const AppSelectionItem({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
  });
}

class AppSelectionDialog<T> extends StatefulWidget {
  final String dialogTitle;
  final String? dialogSubtitle;
  final IconData? dialogIcon;
  final List<AppSelectionItem<T>> items;
  final T currentValue;
  final ValueChanged<T> onSelected;
  final String confirmText;
  final String cancelText;

  const AppSelectionDialog({
    super.key,
    required this.dialogTitle,
    this.dialogSubtitle,
    this.dialogIcon,
    required this.items,
    required this.currentValue,
    required this.onSelected,
    this.confirmText = '确定',
    this.cancelText = '取消',
  });

  @override
  State<AppSelectionDialog<T>> createState() => _AppSelectionDialogState<T>();

  /// 便捷显示方法
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? icon,
    required List<AppSelectionItem<T>> items,
    required T currentValue,
    String confirmText = '确定',
    String cancelText = '取消',
  }) async {
    T? result;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'AppSelectionDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => AppSelectionDialog<T>(
        dialogTitle: title,
        dialogSubtitle: subtitle,
        dialogIcon: icon,
        items: items,
        currentValue: currentValue,
        confirmText: confirmText,
        cancelText: cancelText,
        onSelected: (value) => result = value,
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    return result;
  }
}

class _AppSelectionDialogState<T> extends State<AppSelectionDialog<T>> {
  late T _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final isIpad = context.ipad;
    final screenWidth = MediaQuery.of(context).size.width;

    // 弹窗尺寸策略：
    // - iPad: 固定宽度 450，居中显示，不随屏幕缩放
    // - iPhone: 屏幕宽度的 85%，限制在 300-400 之间
    final dialogWidth = isIpad
        ? 450.0
        : (screenWidth * 0.85).clamp(300.0, 400.0);
    final horizontalPadding = (screenWidth - dialogWidth) / 2;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: dialogWidth),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(isIpad ? 16 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
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
                  child: Column(
                    children: [
                      if (widget.dialogIcon != null) ...[
                        Container(
                          padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.dialogIcon,
                            size: adaptive.Adaptive.icon(28),
                            color: cs.primary,
                          ),
                        ),
                        SizedBox(height: adaptive.Adaptive.h(10)),
                      ],
                      Text(
                        widget.dialogTitle,
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(17),
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      if (widget.dialogSubtitle != null) ...[
                        SizedBox(height: adaptive.Adaptive.h(4)),
                        Text(
                          widget.dialogSubtitle!,
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(13),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── 选项区 ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(20)),
                  child: Column(
                    children: [
                      for (int i = 0; i < widget.items.length; i++) ...[
                        if (i > 0) SizedBox(height: adaptive.Adaptive.h(10)),
                        _SelectionOption(
                          icon: widget.items[i].icon,
                          title: widget.items[i].title,
                          subtitle: widget.items[i].subtitle,
                          isSelected: widget.items[i].value == _selected,
                          onTap: () => setState(() => _selected = widget.items[i].value),
                        ),
                      ],
                    ],
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
                          text: widget.cancelText,
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
                          text: widget.confirmText,
                          size: TDButtonSize.large,
                          type: TDButtonType.fill,
                          theme: TDButtonTheme.primary,
                          shape: TDButtonShape.round,
                          height: adaptive.Adaptive.h(48),
                          style: TDButtonStyle(
                            backgroundColor: AppColors.primary,
                            textColor: AppColors.onPrimary,
                          ),
                          onTap: () => widget.onSelected(_selected),
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

/// 卡片式选项组件（带图标的选项）
class _SelectionOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.s(16),
          vertical: context.s(14),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : cs.surfaceContainerLow,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(context.rs(12)),
        ),
        child: Row(
          children: [
            Container(
              width: context.s(44),
              height: context.s(44),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
              child: Icon(
                icon,
                size: context.is_(24),
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            SizedBox(width: context.s(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.ts(15),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: context.s(2)),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: context.ts(12),
                        color: isSelected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: context.s(22),
                height: context.s(22),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: context.is_(14),
                  color: cs.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 选择对话框（基于 AppBaseDialog，简单列表风格）
// ═══════════════════════════════════════════════════════════════

class AppComboboxDialog<T> {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required T currentValue,
    required String Function(T) itemBuilder,
    String confirmText = '确定',
    String cancelText = '取消',
  }) async {
    T selectedValue = currentValue;

    final result = await showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final cs = Theme.of(ctx).colorScheme;
          return AppBaseDialog(
            title: title,
            actions: [
              AppBaseDialog.cancelButton(
                ctx,
                text: cancelText,
                onTap: () => Navigator.of(ctx).pop(null),
              ),
              AppBaseDialog.confirmButton(
                ctx,
                text: confirmText,
                onTap: () => Navigator.of(ctx).pop(selectedValue),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items.map((item) {
                final isSelected = item == selectedValue;
                return InkWell(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
                  onTap: () => setState(() => selectedValue = item),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w( 14),
                      vertical: adaptive.Adaptive.h( 12),
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer.withValues(alpha: 0.4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            itemBuilder(item),
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp( 15),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected ? cs.primary : cs.onSurface,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            size: adaptive.Adaptive.sp( 20),
                            color: cs.primary,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );

    return result;
  }
}

// ═══════════════════════════════════════════════════════════════
// Toast / 轻提示
// ═══════════════════════════════════════════════════════════════

class AppToast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
  }) {
    switch (type) {
      case ToastType.success:
        TDToast.showSuccess(message, context: context);
        break;
      case ToastType.error:
        TDToast.showFail(message, context: context);
        break;
      case ToastType.warning:
        TDToast.showWarning(message, context: context);
        break;
      case ToastType.info:
        TDToast.showText(message, context: context);
        break;
    }
  }
}

enum ToastType { success, error, warning, info }

// ═══════════════════════════════════════════════════════════════
// 底部操作列表
// ═══════════════════════════════════════════════════════════════

class AppActionSheet {
  static Future<AppActionSheetItem?> show(
    BuildContext context, {
    String? title,
    required List<AppActionSheetItem> items,
  }) async {
    AppActionSheetItem? result;
    final tdItems = items
        .map(
          (item) => TDActionSheetItem(
            label: item.text,
            icon: item.icon != null ? Icon(item.icon!, size: adaptive.Adaptive.icon(22)) : null,
            textStyle: item.destructive
                ? TextStyle(color: context.colors.error)
                : null,
          ),
        )
        .toList();

    TDActionSheet.showListActionSheet(
      context,
      items: tdItems,
      cancelText: '取消',
      showCancel: true,
      onSelected: (selectedItem, index) {
        result = items[index];
      },
    );

    return result;
  }
}

class AppActionSheetItem {
  final String text;
  final String value;
  final IconData? icon;
  final bool destructive;
  final VoidCallback? onTap;

  const AppActionSheetItem({
    required this.text,
    required this.value,
    this.icon,
    this.destructive = false,
    this.onTap,
  });
}

// ═══════════════════════════════════════════════════════════════
// 底部弹出菜单
// ═══════════════════════════════════════════════════════════════

class AppBottomSheetMenu extends StatelessWidget {
  final String? title;
  final List<AppBottomSheetMenuItem> items;

  const AppBottomSheetMenu({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          adaptive.Adaptive.w(16),
          adaptive.Adaptive.h(8),
          adaptive.Adaptive.w(16),
          adaptive.Adaptive.h(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (i) {
                    final item = items[i];
                    return TDCell(
                      title: item.text,
                      leftIconWidget: item.icon != null
                          ? Icon(item.icon!, size: adaptive.Adaptive.icon(22))
                          : null,
                      note: item.subtitle,
                      arrow: false,
                      style: TDCellStyle(
                        titleStyle: TextStyle(
                          fontSize: adaptive.Adaptive.sp(adaptive.isIPad() ? 16 : 14),
                          color: item.destructive
                              ? context.colors.error
                              : cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onClick: (_) {
                        Navigator.of(context).pop(item);
                        item.onTap?.call();
                      },
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<AppBottomSheetMenuItem?> show(
    BuildContext context, {
    String? title,
    required List<AppBottomSheetMenuItem> items,
  }) {
    final cs = context.colors;
    return showModalBottomSheet<AppBottomSheetMenuItem>(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(adaptive.Adaptive.r(16)),
        ),
      ),
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: AppBottomSheetMenu(title: title, items: items),
      ),
    );
  }
}

class AppBottomSheetMenuItem {
  final String text;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback? onTap;

  const AppBottomSheetMenuItem({
    required this.text,
    this.subtitle,
    this.icon,
    this.trailing,
    this.destructive = false,
    this.onTap,
  });
}
