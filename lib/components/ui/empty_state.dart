import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 空状态组件——居中图标 + 标题 + 描述 + 可选操作按钮。
///
/// 支持三种模式：
/// - **默认模式**: Center 包裹，适用于全屏空状态
/// - **紧凑模式** (compact): 无 Center，适用于 ListView/Column 内部
/// - **装饰图标模式** (iconBackground): 图标外层有圆形彩色背景
///
/// 基础规格：
/// - 图标 48pt，颜色 textWeak（#C7C7CC）
/// - 标题 16sp（body），描述 13sp（caption）
/// - 按钮使用 Outlined 样式，品牌色描边
///
/// 使用示例：
/// ```dart
/// // 基础用法
/// EmptyState(
///   icon: Icons.inbox,
///   title: '暂无数据',
///   description: '点击刷新试试',
/// )
///
/// // 带圆形图标背景
/// EmptyState(
///   icon: Icons.folder,
///   title: '暂无文件夹',
///   iconBackgroundColor: Colors.blue.withValues(alpha: 0.08),
///   iconSize: 48,
/// )
///
/// // 紧凑模式（用于 ListView 内）
/// EmptyState.compact(
///   icon: Icons.auto_awesome,
///   title: '暂无AI点评',
///   description: '点击请求点评',
/// )
///
/// // 自定义操作按钮
/// EmptyState(
///   icon: Icons.article,
///   title: '暂无文章',
///   actionLabel: '创建文章',
///   onAction: () {},
///   actionBuilder: (label, onPressed) => TDButton(
///     text: label,
///     onTap: onPressed,
///     type: TDButtonType.fill,
///   ),
/// )
/// ```
class EmptyState extends StatelessWidget {
  /// 图标
  final IconData icon;

  /// 标题文字
  final String title;

  /// 描述文字（可选）
  final String? description;

  /// 操作按钮文字（可选）
  final String? actionLabel;

  /// 操作按钮回调（可选）
  final VoidCallback? onAction;

  /// ==================== 定制化属性 ====================

  /// 图标大小（默认 48）
  final double? iconSize;

  /// 图标颜色（默认 textWeak）
  final Color? iconColor;

  /// 图标背景色（设置后显示圆形背景）
  /// 用于 folder_detail_page、file_list_page 等场景
  final Color? iconBackgroundColor;

  /// 图标背景内边距（默认 20）
  final double? iconBackgroundPadding;

  /// 标题文字样式（覆盖默认样式）
  final TextStyle? titleStyle;

  /// 描述文字样式（覆盖默认样式）
  final TextStyle? descriptionStyle;

  /// 是否紧凑模式（默认 false）
  /// true 时移除 Center 和外层 Padding，适用于 ListView/Column 内部
  /// 用于 ai_evaluation_sheet 等场景
  final bool compact;

  /// 自定义操作按钮构建器
  /// 设置后忽略 actionLabel/onAction，完全自定义按钮
  /// 用于 forum_home_page 等 TDButton 场景
  final Widget Function(String label, VoidCallback onPressed)? actionBuilder;

  /// 内容额外间距（用于紧凑模式调整位置）
  final double? topPadding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    // 定制化属性
    this.iconSize,
    this.iconColor,
    this.iconBackgroundColor,
    this.iconBackgroundPadding,
    this.titleStyle,
    this.descriptionStyle,
    this.compact = false,
    this.actionBuilder,
    this.topPadding,
  });

  // ==================== Factory 构造函数 ====================

  /// 紧凑模式——无 Center 包裹，适用于列表内部
  factory EmptyState.compact({
    Key? key,
    required IconData icon,
    required String title,
    String? description,
    double? topPadding,
    IconData? iconColor,
  }) {
    return EmptyState(
      key: key,
      icon: icon,
      title: title,
      description: description,
      compact: true,
      topPadding: topPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveIconSize = iconSize ?? adaptive.Adaptive.icon(48);
    final effectiveIconColor = iconColor ?? colors.textWeak;

    // 构建图标 Widget
    Widget _buildIcon() {
      final iconWidget = Icon(
        icon,
        size: effectiveIconSize,
        color: effectiveIconColor,
      );

      // 如果有圆形背景，包裹 Container
      if (iconBackgroundColor != null) {
        return Container(
          padding: EdgeInsets.all(iconBackgroundPadding ?? adaptive.Adaptive.w(20)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconBackgroundColor,
          ),
          child: iconWidget,
        );
      }

      return iconWidget;
    }

    // 构建标题 Widget
    Widget _buildTitle() {
      return Text(
        title,
        style: titleStyle ??
            TextStyle(
              fontSize: adaptive.Adaptive.sp(16),
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
        textAlign: TextAlign.center,
      );
    }

    // 构建描述 Widget
    Widget _buildDescription() {
      if (description == null) return const SizedBox.shrink();
      return Text(
        description!,
        style: descriptionStyle ??
            TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              fontWeight: FontWeight.w400,
              color: colors.textWeak,
            ),
        textAlign: TextAlign.center,
      );
    }

    // 构建操作按钮 Widget
    Widget _buildAction() {
      if (actionLabel == null || onAction == null) {
        return const SizedBox.shrink();
      }

      // 如果有自定义按钮构建器
      if (actionBuilder != null) {
        return actionBuilder!(actionLabel!, onAction!);
      }

      // 默认 OutlinedButton
      return OutlinedButton(
        onPressed: onAction,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.primary),
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
          ),
        ),
        child: Text(actionLabel!),
      );
    }

    // 组装内容列
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(),
        SizedBox(height: adaptive.Adaptive.h(iconBackgroundColor != null ? 20 : 16)),
        _buildTitle(),
        if (description != null) ...[
          SizedBox(height: adaptive.Adaptive.h(8)),
          _buildDescription(),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: adaptive.Adaptive.h(20)),
          _buildAction(),
        ],
      ],
    );

    // 根据模式决定布局
    if (compact) {
      // 紧凑模式：不包裹 Center，保留调用方控制的 Padding
      return Padding(
        padding: EdgeInsets.only(top: topPadding ?? adaptive.Adaptive.h(40)),
        child: content,
      );
    }

    // 默认模式：Center 包裹
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: adaptive.Adaptive.h(40),
          horizontal: adaptive.Adaptive.w(32),
        ),
        child: content,
      ),
    );
  }
}
