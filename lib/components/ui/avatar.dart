import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../utils/adaptive.dart';

/// 头像组件
///
/// VidLang 统一头像规范：
/// - 圆形（9999px 圆角）
/// - 支持图片、文字、图标三种模式
/// - 尺寸: XS(32) / SM(40) / MD(48) / LG(64) / XL(80)
/// - 支持点击回调、编辑徽章
///
/// 使用示例：
/// ```dart
/// // 图片头像
/// Avatar(
///   imageUrl: 'https://example.com/avatar.jpg',
///   size: AvatarSize.lg,
/// )
///
/// // 文字头像（自动提取首字母）
/// Avatar(
///   text: '张三',
///   size: AvatarSize.md,
/// )
///
/// // 可点击 + 编辑徽章
/// Avatar(
///   text: '用户名',
///   showEditBadge: true,
///   onTap: () => print('编辑头像'),
/// )
/// ```
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

  /// 点击回调
  final VoidCallback? onTap;

  /// 右下角自定义徽章 Widget
  final Widget? badge;

  /// 是否显示编辑图标徽章（右下角小铅笔图标）
  final bool showEditBadge;

  const Avatar({
    super.key,
    this.imageUrl,
    this.text,
    this.icon,
    this.size = AvatarSize.md,
    this.borderColor,
    this.borderWidth = 2.0,
    this.onTap,
    this.badge,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarContent = Container(
      width: Adaptive.w(size.value),
      height: Adaptive.h(size.value),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: _buildContent(context),
    );

    // 如果需要显示徽章或支持点击，用 Stack 包裹
    if (badge != null || showEditBadge || onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: Adaptive.w(size.value),
          height: Adaptive.h(size.value),
          child: Stack(
            children: [
              avatarContent,
              // 徽章位置：右下角
              if (badge != null || showEditBadge)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: badge ??
                      Container(
                        width: Adaptive.w(size.value * 0.32),
                        height: Adaptive.h(size.value * 0.32),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          AppIcons.edit,
                          size: Adaptive.sp(size.value * 0.18),
                          color: Colors.white,
                        ),
                      ),
                ),
            ],
          ),
        ),
      );
    }

    return avatarContent;
  }

  Widget _buildContent(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // 图片模式
      return ClipOval(
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stackTrace) => _buildTextOrIcon(ctx),
        ),
      );
    } else if (text != null && text!.isNotEmpty) {
      // 文字模式
      return _buildTextOrIcon(context);
    } else {
      // 图标模式（默认）
      return _buildTextOrIcon(context);
    }
  }

  Widget _buildTextOrIcon(BuildContext context) {
    return CircleAvatar(
      radius: Adaptive.w(size.value) / 2,
      backgroundColor: AppColors.primaryBrandLight,
      foregroundColor: AppColors.primaryBrandDark,
      child: text != null && text!.isNotEmpty
          ? Text(
              _getInitials(text!),
              style: TextStyle(
                fontSize: Adaptive.sp(size.fontSize),
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(
              icon ?? AppIcons.person,
              size: Adaptive.sp(size.iconSize),
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
