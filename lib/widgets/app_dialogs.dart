/// TDesign 风格统一弹出组件
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── 对话框脚手架 ────────────────────────────────────────────

class _DialogScaffold extends StatelessWidget {
  final Widget body;
  const _DialogScaffold({required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 311.w,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.all(Radius.circular(12.r)),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  const _DialogButton({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
        child: Center(child: Text(text)),
      ),
    );
  }
}

// ─── 确认对话框（双按钮横向排列） ───────────────────────────

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
    final btnColor = destructive ? cs.error : (confirmColor ?? cs.primary);

    return _DialogScaffold(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface, height: 26 / 18)),
              if (contentWidget != null) ...[SizedBox(height: 8.h), contentWidget!],
              if (contentWidget == null && content.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(content, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp, color: cs.onSurfaceVariant, height: 24 / 16)),
              ],
            ]),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
            child: Row(children: [
              Expanded(
                child: _DialogButton(
                  text: cancelText,
                  backgroundColor: cs.surfaceContainerHighest,
                  foregroundColor: cs.onSurfaceVariant,
                  onTap: () { onCancel?.call(); Navigator.of(context).pop(false); },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _DialogButton(
                  text: confirmText,
                  backgroundColor: btnColor,
                  foregroundColor: cs.onPrimary,
                  onTap: () { onConfirm?.call(); Navigator.of(context).pop(true); },
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

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

// ─── 提示对话框（单按钮） ────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return _DialogScaffold(
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (title != null)
              Text(title!, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface, height: 26 / 18)),
            if (title != null) SizedBox(height: 8.h),
            Text(content, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.sp, color: cs.onSurfaceVariant, height: 24 / 16)),
          ]),
        ),
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
          child: SizedBox(
            width: double.infinity,
            child: _DialogButton(
              text: buttonText,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              onTap: () { onAction?.call(); Navigator.of(context).pop(); },
            ),
          ),
        ),
      ]),
    );
  }

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

// ─── 底部操作列表（选项菜单） ─────────────────────────────────

class AppActionSheet extends StatelessWidget {
  final String? title;
  final List<AppActionSheetItem> items;

  const AppActionSheet({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _DialogScaffold(
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 0),
            child: Text(title!, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ),
        SizedBox(height: (title != null) ? 16.h : 24.h),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i < items.length - 1 ? 12.h : 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(item);
                      item.onTap?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.destructive ? cs.error.withValues(alpha: 0.12) : cs.surfaceContainerHighest,
                      foregroundColor: item.destructive ? cs.error : cs.onSurface,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (item.icon != null) ...[
                        Icon(item.icon, size: 20.sp, color: item.destructive ? cs.error : cs.onSurfaceVariant),
                        SizedBox(width: 8.w),
                      ],
                      Text(item.text),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  static Future<AppActionSheetItem?> show(BuildContext context, {
    String? title,
    required List<AppActionSheetItem> items,
  }) {
    return showGeneralDialog<AppActionSheetItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AppActionSheet',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          AppActionSheet(title: title, items: items),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}



class AppActionSheetItem {
  final String text;
  final String value;
  final IconData? icon;
  final bool destructive;
  final VoidCallback? onTap;
  const AppActionSheetItem({required this.text, required this.value, this.icon, this.destructive = false, this.onTap});
}

// ─── 底部弹出菜单（BottomSheet 风格） ──────────────────────────

class AppBottomSheetMenu extends StatelessWidget {
  final String? title;
  final List<AppBottomSheetMenuItem> items;

  const AppBottomSheetMenu({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(title!, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
          ],
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: item.icon != null ? Icon(item.icon, size: 22.sp, color: item.destructive ? cs.error : cs.onSurfaceVariant) : null,
                    title: Text(item.text,
                        style: TextStyle(fontSize: 14.sp, color: item.destructive ? cs.error : cs.onSurface, fontWeight: FontWeight.w500)),
                    subtitle: item.subtitle != null
                        ? Text(item.subtitle!, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant))
                        : null,
                    trailing: item.trailing,
                    onTap: () {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
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

// ─── SnackBar / Toast 风格提示 ────────────────────────────────

class AppToast {
  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (type) {
      ToastType.success => (Icons.check_circle, Colors.green),
      ToastType.error => (Icons.error, cs.error),
      ToastType.warning => (Icons.warning_amber_rounded, Colors.orange),
      ToastType.info => (Icons.info_outline, cs.primary),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, size: 20.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(message,
                style: TextStyle(color: cs.onSurface, fontSize: 14.sp)),
          ),
        ]),
        backgroundColor: cs.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        duration: const Duration(seconds: 2),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}

enum ToastType { success, error, warning, info }


// ─── 输入对话框 ────────────────────────────────────────────────

class AppInputDialog extends StatelessWidget {
  final String title;
  final String hintText;
  final String initialValue;
  final String confirmText;
  final String cancelText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmit;

  const AppInputDialog({
    super.key,
    required this.title,
    this.hintText = '',
    this.initialValue = '',
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.obscureText = false,
    this.validator,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: initialValue);

    return _DialogScaffold(
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface, height: 26 / 18)),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: obscureText,
              style: TextStyle(color: cs.onSurface, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              ),
            ),
          ]),
        ),
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
          child: Row(children: [
            Expanded(
              child: _DialogButton(
                text: cancelText,
                backgroundColor: cs.surfaceContainerHighest,
                foregroundColor: cs.onSurfaceVariant,
                onTap: () => Navigator.of(context).pop(null),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _DialogButton(
                text: confirmText,
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                onTap: () {
                  final val = controller.text.trim();
                  if (val.isEmpty) return;
                  onSubmit?.call(val);
                  Navigator.of(context).pop(val);
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  static Future<String?> show(BuildContext context, {
    required String title,
    String hintText = '',
    String initialValue = '',
    String confirmText = '确定',
    String cancelText = '取消',
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onSubmit,
  }) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'AppInputDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) => AppInputDialog(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        confirmText: confirmText,
        cancelText: cancelText,
        obscureText: obscureText,
        validator: validator,
        onSubmit: onSubmit,
      ),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

