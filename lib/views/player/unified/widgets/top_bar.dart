import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 统一顶部栏
///
/// 布局设计（基于 V1.2 文档）:
/// - 竖屏: [返回] [标题] [列表]
/// - 横屏: [返回] [文件名] [列表] [设置]
/// - 样式: BackdropFilter 毛玻璃 + 半透明渐变
class TopBar extends StatelessWidget {
  final String title;
  final bool isLandscape;
  final VoidCallback onBack;
  final VoidCallback onToggleDrawer;
  final VoidCallback? onToggleSettings; // 横屏设置按钮
  final bool isDrawerOpen;

  const TopBar({
    super.key,
    required this.title,
    this.isLandscape = false,
    required this.onBack,
    required this.onToggleDrawer,
    this.onToggleSettings,
    this.isDrawerOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,  // 沉浸式模式下保留状态栏安全区
      bottom: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(context, isLandscape ? 12 : 16),
              vertical: adaptive.Adaptive.h(context, isLandscape ? 6 : 8),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // 返回按钮（圆角触控区）
                _buildTouchTarget(
                  context: context,
                  icon: AppIcons.arrowBackIosNew,
                  onTap: onBack,
                  tooltip: '返回',
                ),

                SizedBox(width: adaptive.Adaptive.w(context, 8)),

                // 标题
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: adaptive.Adaptive.sp(context, isLandscape ? 15 : 16),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                SizedBox(width: adaptive.Adaptive.w(context, 8)),

                // 右侧按钮组
                _buildRightButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 右侧按钮组
  Widget _buildRightButtons(BuildContext context) {
    if (isLandscape) {
      // 横屏：列表 + 设置
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTouchTarget(
            context: context,
            icon: AppIcons.list,
            onTap: onToggleDrawer,
            tooltip: '资源列表',
          ),
          if (onToggleSettings != null) ...[
            SizedBox(width: adaptive.Adaptive.w(context, 4)),
            _buildTouchTarget(
              context: context,
              icon: AppIcons.settings,
              onTap: onToggleSettings!,
              tooltip: '播放设置',
            ),
          ],
        ],
      );
    }

    // 竖屏：仅列表
    return _buildTouchTarget(
      context: context,
      icon: isDrawerOpen ? AppIcons.close : AppIcons.list,
      onTap: onToggleDrawer,
      tooltip: isDrawerOpen ? '关闭' : '资源列表',
    );
  }

  /// 圆角触控区域按钮（最小 48×48 触控热区）
  Widget _buildTouchTarget({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final size = adaptive.Adaptive.w(context, 44);
    final iconSize = adaptive.Adaptive.icon(context, 22);

    final widget = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: widget);
    }
    return widget;
  }
}
