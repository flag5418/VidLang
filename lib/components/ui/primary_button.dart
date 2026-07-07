import 'package:flutter/material.dart';
import 'package:vidlang/utils/adaptive.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// 主要按钮组件
/// 
/// 基于 Pencil UI Design Skill 的按钮规范：
/// - 主色调背景 + 白色文字
/// - 8px 圆角（AppRadius.md）
/// - 按压时有缩放效果（scale: 0.98）
/// - 支持加载状态、图标、禁用状态
/// 
/// 使用示例：
/// ```dart
/// PrimaryButton(
///   text: '确认',
///   onPressed: () {},
///   icon: Icons.check,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  /// 按钮文字
  final String text;
  
  /// 点击回调
  final VoidCallback? onPressed;
  
  /// 是否显示加载状态
  final bool isLoading;
  
  /// 按钮前图标
  final IconData? icon;
  
  /// 是否为全宽按钮
  final bool isFullWidth;
  
  /// 自定义背景色（默认使用 primaryBrand）
  final Color? backgroundColor;
  
  /// 自定义文字颜色
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isLoading && onPressed != null;
    
    return _AnimatedButton(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: Adaptive.w(context, AppSpacing.buttonPaddingHorizontal),
          vertical: Adaptive.h(context, AppSpacing.buttonPaddingVertical),
        ),
        decoration: BoxDecoration(
          color: isEnabled 
            ? (backgroundColor ?? AppColors.primaryBrand)
            : AppColors.textDisabled,
          borderRadius: BorderRadius.circular(AppRadius.button),
          // Pencil Skill: 柔和阴影
          boxShadow: isEnabled ? [
            BoxShadow(
              color: (backgroundColor ?? AppColors.primaryBrand).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: Adaptive.w(context, 18),
                height: Adaptive.w(context, 18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
              )
            else if (icon != null)
              Icon(icon, size: Adaptive.w(context, 20), color: textColor ?? Colors.white),
            
            if ((isLoading || icon != null) && text.isNotEmpty)
              SizedBox(width: AppSpacing.sm),
            
            if (!isLoading && text.isNotEmpty)
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: textColor ?? Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 带动画效果的按钮包装器
class _AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _AnimatedButton({required this.child, required this.onTap});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 150), // Pencil Skill: 快速动画
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
