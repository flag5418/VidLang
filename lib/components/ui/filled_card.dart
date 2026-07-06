import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// 实色背景卡片，最高视觉重量。
///
/// 默认使用品牌绿色渐变作为背景，支持自定义背景色/渐变。
/// 圆角 20pt，内边距 20pt，白色文字。
///
/// 使用示例：
/// ```dart
/// FilledCard(
///   child: Text('Hello'),
/// )
/// FilledCard.tinted(
///   child: Text('Embedded'),
/// )
/// ```
class FilledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double? borderRadius;
  final VoidCallback? onTap;

  const FilledCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
  });

  /// 浅色变体——用于词汇卡片等嵌入场景。
  factory FilledCard.tinted({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
  }) {
    return FilledCard(
      key: key,
      child: child,
      padding: padding,
      backgroundColor: const Color(0xFFDCFCE7),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ??
        (backgroundColor == null
            ? AppColors.primaryGradient
            : LinearGradient(colors: [backgroundColor!, backgroundColor!]));

    final bool isDarkBackground = backgroundColor == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: effectiveGradient,
          borderRadius:
              BorderRadius.circular(borderRadius ?? AppRadius.filledCard),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: isDarkBackground ? Colors.white : AppColors.textPrimary,
          ),
          child: child,
        ),
      ),
    );
  }
}
