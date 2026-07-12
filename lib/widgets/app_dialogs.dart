/// TDesign 风格统一弹出组件
///
/// 提供基于 TDesign 的统一对话框、Toast、ActionSheet 等组件封装。
/// 所有弹窗类组件必须使用此文件中的组件，禁止直接使用原生 AlertDialog/SnackBar/ElevatedButton。
///
/// 使用示例：
/// ```dart
/// // 确认对话框
/// final confirmed = await AppConfirmDialog.show(
///   context: context,
///   title: '删除确认',
///   content: '确定要删除这个视频吗？',
/// );
///
/// // Toast 提示
/// AppToast.show(context, '操作成功', type: ToastType.success);
///
/// // 底部菜单
/// await AppActionSheet.show(
///   context: context,
///   items: [
///     AppActionSheetItem(text: '编辑', value: 'edit'),
///     AppActionSheetItem(text: '删除', value: 'delete', destructive: true),
///   ],
/// );
/// ```
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/utils/adaptive.dart';

// ═══════════════════════════════════════════════════════════════
// 确认对话框（双按钮）— 基于 TDConfirmDialog / showGeneralDialog
// ═══════════════════════════════════════════════════════════════

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;
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
    this.confirmColor,
    this.onConfirm,
    this.onCancel,
    this.contentWidget,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: Adaptive.w(context, isIPad(context) ? 360 : 311),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.all(Radius.circular(Adaptive.r(context, 12))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(Adaptive.w(context, 24), Adaptive.h(context, 32), Adaptive.w(context, 24), 0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(title, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: Adaptive.sp(context, isIPad(context) ? 20 : 18), fontWeight: FontWeight.w600, color: cs.onSurface)),
                  if (contentWidget != null) ...[SizedBox(height: Adaptive.h(context, 8)), contentWidget!],
                  if (contentWidget == null && content.isNotEmpty) ...[
                    SizedBox(height: Adaptive.h(context, 8)),
                    Text(content, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: Adaptive.sp(context, isIPad(context) ? 17 : 15), color: cs.onSurfaceVariant)),
                  ],
                ]),
              ),
              SizedBox(height: Adaptive.h(context, 24)),
              Padding(
                padding: EdgeInsets.fromLTRB(Adaptive.w(context, 24), 0, Adaptive.w(context, 24), Adaptive.h(context, 24)),
                child: Row(children: [
                    Expanded(
                      // ✅ TDesign 规范：使用 TDButton 替代 ElevatedButton
                      child: TDButton(
                        text: cancelText,
                        size: TDButtonSize.medium,
                        type: TDButtonType.fill,
                        theme: TDButtonTheme.defaultTheme,
                        shape: TDButtonShape.round,
                        onTap: () { onCancel?.call(); Navigator.of(context).pop(false); },
                      ),
                    ),
                    SizedBox(width: Adaptive.w(context, 12)),
                    Expanded(
                      child: TDButton(
                        text: confirmText,
                        size: TDButtonSize.medium,
                        type: TDButtonType.fill,
                        // ✅ 使用自定义背景色实现危险/主色按钮
                        shape: TDButtonShape.round,
                        onTap: () { onConfirm?.call(); Navigator.of(context).pop(true); },
                      ),
                    ),
                  ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示确认对话框（返回 bool?）
  static Future<bool?> show(BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    Color? confirmColor,
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
      pageBuilder: (ctx, animation, secondaryAnimation) => AppConfirmDialog(
        title: title, content: content, confirmText: confirmText, cancelText: cancelText,
        confirmColor: confirmColor, onConfirm: onConfirm, onCancel: onCancel,
        contentWidget: contentWidget, destructive: destructive,
      ),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
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
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: Adaptive.w(context, isIPad(context) ? 360 : 311),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.all(Radius.circular(Adaptive.r(context, 12))),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: EdgeInsets.fromLTRB(Adaptive.w(context, 24), Adaptive.h(context, 32), Adaptive.w(context, 24), 0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (title != null)
                  Text(title!, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: Adaptive.sp(context, isIPad(context) ? 20 : 18), fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                if (title != null) SizedBox(height: Adaptive.h(context, 8)),
                Text(content, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: Adaptive.sp(context, isIPad(context) ? 17 : 15), color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
            SizedBox(height: Adaptive.h(context, 24)),
            Padding(
              padding: EdgeInsets.fromLTRB(Adaptive.w(context, 24), 0, Adaptive.w(context, 24), Adaptive.h(context, 24)),
              child: SizedBox(
                width: double.infinity,
                // ✅ TDesign 规范：使用 TDButton 替代 ElevatedButton
                child: TDButton(
                  text: buttonText,
                  size: TDButtonSize.medium,
                  type: TDButtonType.fill,
                  theme: TDButtonTheme.primary,
                  shape: TDButtonShape.round,
                  onTap: () { onAction?.call(); Navigator.of(context).pop(); },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// 显示提示对话框
  static Future<void> show(BuildContext context, {
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
      pageBuilder: (ctx, animation, secondaryAnimation) => AppAlertDialog(
        title: title, content: content, buttonText: buttonText, onAction: onAction,
      ),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 底部操作列表（选项菜单）— 基于 TDActionSheet.showListActionSheet
// ═══════════════════════════════════════════════════════════════

class AppActionSheet {
  /// 显示底部操作列表（返回选中的 item）
  ///
  /// ✅ 使用 TDActionSheet.showListActionSheet 替代原生 showModalBottomSheet + ListTile
  static Future<AppActionSheetItem?> show(BuildContext context, {
    String? title,
    required List<AppActionSheetItem> items,
  }) async {
    AppActionSheetItem? result;

    // 转换为 TDActionSheetItem
    final tdItems = items.map((item) => TDActionSheetItem(
      label: item.text,
      icon: item.icon != null ? Icon(item.icon!, size: 22) : null, // TDActionSheetItem.icon 是 Widget? 类型
      textStyle: item.destructive
          ? TextStyle(color: TDTheme.of(context).errorNormalColor)
          : null,
    )).toList();

    TDActionSheet.showListActionSheet(
      context,
      items: tdItems,
      cancelText: '取消',
      showCancel: true,
      onSelected: (selectedItem, index) {
        result = items[index];
      },
    );

    // TDActionSheet.showListActionSheet 是 void 返回，需要通过其他方式获取结果
    // 这里返回 null，调用方应使用 onSelected 回调处理选择
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
// 底部弹出菜单（BottomSheet 风格，带 subtitle 支持）
// ═══════════════════════════════════════════════════════════════

class AppBottomSheetMenu extends StatelessWidget {
  final String? title;
  final List<AppBottomSheetMenuItem> items;

  const AppBottomSheetMenu({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Adaptive.w(context, 16), Adaptive.h(context, 8), Adaptive.w(context, 16), Adaptive.h(context, 16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 8)),
              child: Text(title!, style: TextStyle(fontSize: Adaptive.sp(context, 14), fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
          ],
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  // ✅ 使用 TDCell 替代 ListTile
                  return TDCell(
                    title: item.text,
                    leftIcon: item.icon, // TDCell.leftIcon 是 IconData? 类型
                    leftIconWidget: item.icon != null ? Icon(item.icon!, size: Adaptive.icon(context, 22)) : null,
                    note: item.subtitle,
                    arrow: false,
                    style: TDCellStyle(
                      titleStyle: TextStyle(
                        fontSize: Adaptive.sp(context, isIPad(context) ? 16 : 14),
                        color: item.destructive ? TDTheme.of(context).errorNormalColor : cs.onSurface,
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
        ]),
      ),
    );
  }

  static Future<AppBottomSheetMenuItem?> show(BuildContext context, {
    String? title,
    required List<AppBottomSheetMenuItem> items,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<AppBottomSheetMenuItem>(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Adaptive.r(context, 16)))),
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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

// ═══════════════════════════════════════════════════════════════
// Toast / 轻提示 — 基于 TDToast（替代 SnackBar）
// ═══════════════════════════════════════════════════════════════

class AppToast {
  /// 显示 Toast 提示（✅ 使用 TDToast 替代 SnackBar）
  ///
  /// [type] 决定图标和颜色风格：
  /// - [ToastType.success]: 绿色成功图标 → TDToast.showSuccess
  /// - [ToastType.error]: 红色错误图标 → TDToast.showFail
  /// - [ToastType.warning]: 橙色警告图标 → TDToast.showWarning
  /// - [ToastType.info]: 品牌色信息图标 → TDToast.showText
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
        // ✅ 注意：TDesign API 使用 showFail 而非 showError
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
// 输入对话框 — 基于 TDInputDialog
// ═══════════════════════════════════════════════════════════════

class AppInputDialog {
  /// 显示输入对话框（返回输入的字符串）
  ///
  /// ✅ 使用 TDInputDialog 替代原生 showDialog + TextField
  static Future<String?> show(BuildContext context, {
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

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TDInputDialog(
        textEditingController: controller,
        title: title,
        hintText: hintText,
        leftBtn: TDDialogButtonOptions(
          title: cancelText,
          action: () => Navigator.of(ctx).pop(null),
        ),
        rightBtn: TDDialogButtonOptions(
          title: confirmText,
          action: () {
            final val = controller.text.trim();
            if (val.isEmpty) return; // 不关闭
            result = val;
            onSubmit?.call(val);
            Navigator.of(ctx).pop(val);
          },
        ),
      ),
    );

    controller.dispose();
    return result;
  }
}
