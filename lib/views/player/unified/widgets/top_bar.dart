import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 统一顶部栏
///
/// 布局设计（V2.0 重构，参考 deepenglish_pad VideoPlayerBase 第2756-2816行）:
/// - 竖屏: [返回] [标题] [列表]
/// - 横屏: [返回] [文件名] [列表] [设置]
/// - 样式: 渐变透明背景（black87 → transparent），无 SafeArea/BackdropFilter
class TopBar extends StatelessWidget {
  final String title;
  final bool isLandscape;
  final VoidCallback onBack;
  final VoidCallback onToggleDrawer;
  final VoidCallback? onToggleSettings; // 横屏设置按钮
  final bool isDrawerOpen;

  /// 右侧预留空间（pt）：为视频右上角的全屏按钮让出位置（横屏时使用）
  /// 同时将该区域的背景渐变裁掉，使底层 MediaArea 的全屏按钮可透出
  final double trailingRightInset;

  const TopBar({
    super.key,
    required this.title,
    this.isLandscape = false,
    required this.onBack,
    required this.onToggleDrawer,
    this.onToggleSettings,
    this.isDrawerOpen = false,
    this.trailingRightInset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // 手动获取状态栏高度（替代 SafeArea，避免在沉浸式模式下占用额外空间）
    final topPadding = MediaQuery.of(context).padding.top;
    final barHeight = adaptive.Adaptive.h(isLandscape ? 44 : 52);

    debugPrint('🔝 TopBar.build: '
        'isLandscape=$isLandscape, '
        'topPadding=$topPadding, '
        'barHeight=$barHeight, '
        'totalHeight=${topPadding + barHeight}');

    return Stack(
      children: [
        // 背景渐变（右侧按 trailingRightInset 裁掉，避免遮挡全屏按钮）
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          right: trailingRightInset,
          child: Container(
            // V2.0：使用轻量渐变替代 BackdropFilter 毛玻璃
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87, // 顶部深色（不透明）
                  Colors.black54, // 中间半透明
                  Colors.transparent, // 底部完全透明
                ],
              ),
            ),
          ),
        ),

        // 内容行
        Container(
          padding: EdgeInsets.only(
            left: adaptive.Adaptive.w(isLandscape ? 12 : 16),
            right: adaptive.Adaptive.w(isLandscape ? 12 : 16) + trailingRightInset,
            top: topPadding, // 手动处理状态栏
          ),
          height: topPadding + barHeight,
          child: Row(
            children: [
              // 返回按钮（圆角触控区）
              _buildTouchTarget(
                context: context,
                icon: AppIcons.arrowBackIosNew,
                onTap: onBack,
                tooltip: '返回',
              ),

              SizedBox(width: adaptive.Adaptive.w(8)),

              // 标题
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: adaptive.Adaptive.sp(isLandscape ? 15 : 16),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(width: adaptive.Adaptive.w(8)),

              // 右侧按钮组
              _buildRightButtons(context),
            ],
          ),
        ),
      ],
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
            SizedBox(width: adaptive.Adaptive.w(4)),
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
    final size = adaptive.Adaptive.w(44);
    final iconSize = adaptive.Adaptive.icon(22);

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
