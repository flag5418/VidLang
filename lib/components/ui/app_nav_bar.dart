/// 通用导航栏组件（AppNavBar）
///
/// 统一所有页面的 AppBar 实现，解决以下问题：
/// 1. 返回按钮图标/样式统一
/// 2. 左右间距统一（基于 AppSpacing.pagePaddingHorizontal = 16）
/// 3. 标题样式统一
/// 4. 支持自定义 actions / bottom widget
///
/// 使用示例：
/// ```dart
/// // 基础用法 — 自动返回按钮 + 居中标题
/// AppBar(
///   leading: AppNavBar.buildLeading(context),
///   title: AppNavBar.buildTitle('页面标题'),
/// )
///
/// // 完整用法 — 带 actions
/// AppNavBar(
///   context: context,
///   title: '设置',
///   actions: [IconButton(icon: ...)],
/// )
///
/// // 直接作为 PreferredSizeWidget 使用
/// Scaffold(
///   appBar: AppNavBar(context: context, title: '详情'),
///   ...
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  /// 页面标题
  final String title;

  /// 自定义标题 Widget（优先于 [title]）
  final Widget? titleWidget;

  /// 右侧操作按钮列表
  final List<Widget>? actions;

  /// 底部 Widget（如 TabBar）
  final PreferredSizeWidget? bottom;

  /// 背景色
  final Color? backgroundColor;

  /// 前景色（标题、图标颜色）
  final Color? foregroundColor;

  /// 阴影高度
  final double elevation;

  /// 滚动时阴影高度
  final double? scrolledUnderElevation;

  /// 是否自动添加返回按钮（默认 true）
  /// 设为 false 可完全自定义 leading，或用于首页等不需要返回的页面
  final bool showBackButton;

  /// 返回按钮回调（默认 Navigator.pop）
  final VoidCallback? onBack;

  /// 标题是否居中（默认 true）
  final bool centerTitle;

  /// 内边距（左右），默认使用 AppSpacing.pagePaddingHorizontal
  /// 注意：Flutter AppBar 的 leading/leadingWidth 和 actions 区域
  /// 已内置标准间距，此处保留参数供未来扩展使用
  final double? horizontalPadding;

  const AppNavBar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.scrolledUnderElevation,
    this.showBackButton = true,
    this.onBack,
    this.centerTitle = true,
    this.horizontalPadding,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  /// 构建统一的返回按钮 Leading
  static Widget buildLeading(
    BuildContext context, {
    VoidCallback? onBack,
    Color? color,
  }) {
    final foregroundColor =
        color ?? Theme.of(context).appBarTheme.foregroundColor ?? AppColors.onSurface;
    
    return IconButton(
      icon: Icon(
        AppIcons.arrowBackIosNew,
        size: adaptive.Adaptive.icon(20),
        color: foregroundColor,
      ),
      onPressed: onBack ?? () => Navigator.maybePop(context),
      tooltip: '返回',
      constraints: BoxConstraints(
        minWidth: adaptive.Adaptive.w(44),
        minHeight: adaptive.Adaptive.h(44),
      ),
      padding: EdgeInsets.zero,
    );
  }

  /// 构建统一样式的标题
  static Widget buildTitle(
    String text, {
    Color? color,
    Widget? customWidget,
  }) {
    if (customWidget != null) return customWidget;

    // 如果未指定颜色，使用传入的 color 或默认值
    final themeColor = color ?? AppColors.textPrimary;

    return Text(
      text,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(17),
        fontWeight: FontWeight.w600,
        color: themeColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    final Color surfaceBg = backgroundColor ??
        theme.appBarTheme.backgroundColor ??
        AppColors.getSurfaceHighest(brightness: brightness);
    final Color fgColor = foregroundColor ??
        theme.appBarTheme.foregroundColor ??
        (brightness == Brightness.dark ? AppColors.onSurface : AppColors.textPrimary);

    return AppBar(
      title: titleWidget ?? buildTitle(title, color: fgColor),
      centerTitle: centerTitle,
      backgroundColor: surfaceBg,
      foregroundColor: fgColor,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      leading: showBackButton ? buildLeading(context, onBack: onBack, color: fgColor) : null,
      actions: actions,
      bottom: bottom,
      // 统一控制内边距
      titleSpacing: 0,
      toolbarHeight: kToolbarHeight,
    );
  }
}
