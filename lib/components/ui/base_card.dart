import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 基础卡片组件
/// 
/// 基于 Pencil UI Design Skill 的卡片规范：
/// - 白色背景（亮色模式）/ #18181B（暗色模式）
/// - 16px 大圆角
/// - 柔和阴影: 0 4px 12px rgba(0,0,0,0.05)
/// - 可选边框: 1px outline
/// 
/// 使用示例：
/// ```dart
/// BaseCard(
///   onTap: () {},
///   child: Text('Card Content'),
/// )
/// ```
class BaseCard extends StatelessWidget {
  /// 卡片内容
  final Widget child;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 内边距
  final EdgeInsetsGeometry? padding;
  
  /// 外边距
  final EdgeInsetsGeometry? margin;
  
  /// 是否显示边框
  final bool showBorder;
  
  /// 自定义圆角
  final double? borderRadius;
  
  /// 自定义背景色
  final Color? backgroundColor;

  const BaseCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: margin ?? EdgeInsets.all(AppSpacing.sm),
      padding: padding ?? EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.card),
        border: showBorder 
          ? Border.all(color: theme.colorScheme.outlineVariant)
          : null,
        // Pencil Skill: 柔和阴影
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: adaptive.Adaptive.w(context, 6),
            offset: Offset(0, 2),
          ),
        ],
      ),
      // 点击效果
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.card),
          splashColor: AppColors.primaryBrand.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryBrand.withValues(alpha: 0.05),
          child: child,
        ),
      ),
    );
  }
}

/// 带标题的卡片组件
class TitledCard extends StatelessWidget {
  /// 标题
  final String title;
  
  /// 副标题（可选）
  final String? subtitle;
  
  /// 标题前的图标（可选）
  final IconData? leadingIcon;
  
  /// 标题后的操作按钮（可选）
  final List<Widget>? actions;
  
  /// 卡片内容
  final Widget child;
  
  /// 点击回调
  final VoidCallback? onTap;

  const TitledCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.actions,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              if (leadingIcon != null)
                Icon(leadingIcon, size: adaptive.Adaptive.icon(context, 20), color: AppColors.textSecondary),
              
              if (leadingIcon != null)
                SizedBox(width: AppSpacing.sm),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              ...?actions,
            ],
          ),
          
          SizedBox(height: AppSpacing.md),
          
          // 内容区域
          child,
        ],
      ),
    );
  }
}
