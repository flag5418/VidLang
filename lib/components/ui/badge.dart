import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// 徽章组件
/// 
/// 基于 Pencil UI Design Skill 的徽章规范：
/// - 高度: 22px
/// - 内边距: 6px 水平, 8px 垂直
/// - 圆角: 6px (AppRadius.sm)
/// - 字体大小: 10px, 字重: 500
class Badge extends StatelessWidget {
  /// 显示的文字
  final String text;
  
  /// 徽章颜色
  final Color? backgroundColor;
  
  /// 文字颜色
  final Color? textColor;
  
  /// 前缀图标
  final IconData? icon;

  const Badge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.w,
        vertical: 6.h,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceSecondaryLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14.w, color: textColor ?? AppColors.textSecondary),
          
          if (icon != null)
            SizedBox(width: 4.w),
          
          Text(
            text,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: textColor ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 预定义的语义化徽章

/// 成功状态徽章
class SuccessBadge extends StatelessWidget {
  final String text;
  
  const SuccessBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Badge(
      text: text,
      backgroundColor: AppColors.primaryBrandLight,
      textColor: AppColors.primaryBrandDark,
      icon: Icons.check_circle_outline,
    );
  }
}

/// 警告状态徽章
class WarningBadge extends StatelessWidget {
  final String text;
  
  const WarningBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Badge(
      text: text,
      backgroundColor: const Color(0xFFFEF3C7),
      textColor: const Color(0xFFD97706),
      icon: Icons.warning_amber_outlined,
    );
  }
}

/// 错误状态徽章
class ErrorBadge extends StatelessWidget {
  final String text;
  
  const ErrorBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Badge(
      text: text,
      backgroundColor: const Color(0xFFFEE2E2),
      textColor: AppColors.error,
      icon: Icons.error_outline,
    );
  }
}

/// 信息状态徽章
class InfoBadge extends StatelessWidget {
  final String text;
  
  const InfoBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Badge(
      text: text,
      backgroundColor: const Color(0xFFDBEAFE),
      textColor: AppColors.info,
      icon: Icons.info_outline,
    );
  }
}
