import 'package:flutter/material.dart';

/// 安全的 Dialog 工具
///
/// 新版 Flutter 的 showDialog 内部使用了 Windowing API，
/// 在 Android 上会抛出 "Windowing is unsupported on this platform"。
/// 此工具类统一使用 showGeneralDialog 规避该问题。
class DialogUtils {
  DialogUtils._();

  /// 替代 showDialog，兼容所有平台
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x80000000),
    String barrierLabel = '',
    RouteSettings? routeSettings,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      pageBuilder: (ctx, _, _) => builder(ctx),
      routeSettings: routeSettings,
    );
  }
}
