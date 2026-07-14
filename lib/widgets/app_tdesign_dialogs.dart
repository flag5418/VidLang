/// TDesign 风格统一弹出组件
///
/// 提供基于 TDesign 的统一对话框、Toast、ActionSheet 等组件封装。
/// 所有弹窗类组件必须使用此文件中的组件，禁止直接使用原生 AlertDialog/SnackBar。
///
/// 使用示例：
/// ```dart
/// // Toast 提示
/// AppTToast.success(context, '操作成功');
/// AppTToast.error(context, '网络错误');
///
/// // 底部菜单
/// await AppTActionSheet.show(
///   context: context,
///   items: [
///     AppTActionSheetItem(text: '编辑', value: 'edit'),
///     AppTActionSheetItem(text: '删除', value: 'delete', destructive: true),
///   ],
/// );
/// ```
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

// ═══════════════════════════════════════════════════════════════
// TDesign Toast 封装 (AppTToast)
// ═══════════════════════════════════════════════════════════════

class AppTToast {
  /// 显示普通信息 Toast
  static void info(BuildContext context, String message) {
    TDToast.showText(message, context: context);
  }

  /// 显示成功 Toast
  static void success(BuildContext context, String message) {
    TDToast.showSuccess(message, context: context);
  }

  /// 显示警告 Toast
  static void warning(BuildContext context, String message) {
    TDToast.showWarning(message, context: context);
  }

  /// 显示错误 Toast（使用 showFail 替代 showError）
  static void error(BuildContext context, String message) {
    TDToast.showFail(message, context: context);
  }
}

// ═══════════════════════════════════════════════════════════════
// TDesign ActionSheet 封装 (AppTActionSheet)
// ═══════════════════════════════════════════════════════════════

class AppTActionSheetItem {
  final String text;
  final String value;
  final bool destructive;
  final VoidCallback? onTap;

  const AppTActionSheetItem({
    required this.text,
    required this.value,
    this.destructive = false,
    this.onTap,
  });
}

class AppTActionSheet {
  /// 显示底部操作列表
  ///
  /// ```dart
  /// final result = await AppTActionSheet.show(
  ///   context: context,
  ///   title: '选择操作',
  ///   items: [
  ///     AppTActionSheetItem(text: '编辑', value: 'edit'),
  ///     AppTActionSheetItem(text: '删除', value: 'delete', destructive: true),
  ///   ],
  /// );
  /// if (result != null) { ... }
  /// ```
  static Future<AppTActionSheetItem?> show(
    BuildContext context, {
    String? title,
    required List<AppTActionSheetItem> items,
  }) async {
    return showModalBottomSheet<AppTActionSheetItem>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TDActionSheetContent(title: title, items: items),
    );
  }
}

class _TDActionSheetContent extends StatelessWidget {
  final String? title;
  final List<AppTActionSheetItem> items;

  const _TDActionSheetContent({this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  adaptive.Adaptive.w(context, 24),
                  adaptive.Adaptive.h(context, 20),
                  adaptive.Adaptive.w(context, 24),
                  adaptive.Adaptive.h(context, 8),
                ),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(context, 14),
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              Divider(height: 1),
            ],
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              
              return ListTile(
                title: Text(
                  item.text,
                  style: TextStyle(
                    color: item.destructive 
                        ? context.colors.error 
                        : null,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(item);
                  item.onTap?.call();
                },
              );
            }),
            SizedBox(height: adaptive.Adaptive.h(context, 8)),
            // 取消按钮
            Divider(height: 1),
            ListTile(
              title: Text('取消'),
              onTap: () => Navigator.of(context).pop(null),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 0 : adaptive.Adaptive.h(context, 16)),
          ],
        ),
      ),
    );
  }
}
