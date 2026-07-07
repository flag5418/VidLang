import 'package:flutter/material.dart';
import 'package:vidlang/utils/adaptive.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// 次要按钮组件
/// 
/// 基于 Pencil UI Design Skill 的按钮规范：
/// - 背景: #F4F4F5（surfaceSecondary）
/// - 边框: 1px #E4E4E7
/// - 文字: #18181B（textPrimary）
/// - 圆角: 8px
/// 
/// 使用场景：次要操作、取消按钮、返回按钮等
class SecondaryButton extends StatelessWidget {
  /// 按钮文字
  final String text;
  
  /// 点击回调
  final VoidCallback? onPressed;
  
  /// 按钮前图标
  final IconData? icon;
  
  /// 是否为全宽按钮
  final bool isFullWidth;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: Adaptive.w(context, AppSpacing.buttonPaddingHorizontal),
          vertical: Adaptive.h(context, AppSpacing.buttonPaddingVertical),
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondaryLight,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: Adaptive.w(context, 20), color: AppColors.textPrimary),
            
            if (icon != null && text.isNotEmpty)
              SizedBox(width: AppSpacing.sm),
            
            if (text.isNotEmpty)
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
