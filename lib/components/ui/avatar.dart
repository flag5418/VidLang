import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

/// 头像组件
/// 
/// 基于 Pencil UI Design Skill 的头像规范：
/// - 圆形（9999px 圆角）
/// - 支持图片、文字、图标三种模式
/// - 尺寸: XS(32) / SM(40) / MD(48) / LG(64) / XL(80)
class Avatar extends StatelessWidget {
  /// 头像 URL 或路径
  final String? imageUrl;
  
  /// 显示的文字（当 imageUrl 为空时使用）
  final String? text;
  
  /// 显示的图标（当 imageUrl 和 text 都为空时使用）
  final IconData? icon;
  
  /// 头像尺寸
  final AvatarSize size;
  
  /// 边框颜色
  final Color? borderColor;
  
  /// 边框宽度
  final double borderWidth;

  const Avatar({
    super.key,
    this.imageUrl,
    this.text,
    this.icon,
    this.size = AvatarSize.md,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.value.w,
      height: size.value.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : null,
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // 图片模式
      return ClipOval(
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => 
            _buildTextOrIcon(),
        ),
      );
    } else if (text != null && text!.isNotEmpty) {
      // 文字模式
      return _buildTextOrIcon();
    } else {
      // 图标模式（默认）
      return _buildTextOrIcon();
    }
  }

  Widget _buildTextOrIcon() {
    return CircleAvatar(
      radius: size.value.w / 2,
      backgroundColor: AppColors.primaryBrandLight,
      foregroundColor: AppColors.primaryBrandDark,
      child: text != null && text!.isNotEmpty
        ? Text(
            _getInitials(text!),
            style: TextStyle(
              fontSize: size.fontSize.sp,
              fontWeight: FontWeight.w600,
            ),
          )
        : Icon(
            icon ?? Icons.person,
            size: size.iconSize.w,
          ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

/// 头像尺寸枚举
enum AvatarSize {
  xs(32.0, 12.0, 16.0),
  sm(40.0, 14.0, 20.0),
  md(48.0, 16.0, 24.0),
  lg(64.0, 20.0, 32.0),
  xl(80.0, 24.0, 40.0);

  const AvatarSize(this.value, this.fontSize, this.iconSize);
  
  final double value;
  final double fontSize;
  final double iconSize;
}
