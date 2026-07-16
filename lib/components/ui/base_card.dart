import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 基础卡片组件
///
/// VidLang 统一卡片规范：
/// - 默认无外边距、无内边距（由调用方控制）
/// - 默认无边框（按需开启）
/// - 支持三种变体：outlined（描边）、elevated（阴影）、filled（实色）
/// - 可选按压缩放动画
/// - 主题自适应（亮/暗色模式）
///
/// 使用示例：
/// ```dart
/// // 基础用法
/// BaseCard(
///   padding: EdgeInsets.all(16),
///   child: Text('内容'),
/// )
///
/// // 描边卡片
/// BaseCard.outlined(
///   padding: EdgeInsets.all(16),
///   child: Text('带边框'),
/// )
///
/// // 阴影卡片
/// BaseCard.elevated(
///   onTap: () {},
///   child: Text('可点击'),
/// )
///
/// // 实色背景卡片
/// BaseCard.filled(
///   backgroundColor: AppColors.primaryBrandLight,
///   child: Text('强调内容'),
/// )
/// ```
class BaseCard extends StatelessWidget {
  /// 卡片内容
  final Widget child;

  /// 点击回调
  final VoidCallback? onTap;

  /// 内边距（默认 null，不强制设置）
  final EdgeInsetsGeometry? padding;

  /// 外边距（默认 null，不强制设置）
  final EdgeInsetsGeometry? margin;

  /// 是否显示边框
  final bool showBorder;

  /// 自定义圆角
  final double? borderRadius;

  /// 自定义背景色
  final Color? backgroundColor;

  /// 自定义阴影（null 时根据 showBorder 自动决定）
  final List<BoxShadow>? boxShadow;

  /// 是否启用按压缩放动画（默认 false）
  final bool enableScaleAnimation;

  /// 内容裁剪模式
  final Clip clipBehavior;

  const BaseCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.showBorder = false,
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
    this.enableScaleAnimation = false,
    this.clipBehavior = Clip.none,
  });

  // ==================== Factory 构造函数 ====================

  /// 描边卡片——白色背景 + 细边框 + 无阴影
  ///
  /// 适用于：设置项、表单区域、信息展示
  factory BaseCard.outlined({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? borderRadius,
    Color? backgroundColor,
    VoidCallback? onTap,
    bool enableScaleAnimation = false,
  }) {
    return BaseCard(
      key: key,
      padding: padding,
      margin: margin,
      showBorder: true,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      boxShadow: null, // 无阴影
      onTap: onTap,
      enableScaleAnimation: enableScaleAnimation,
      child: child,
    );
  }

  /// 阴影卡片——白色背景 + 柔和阴影 + 可选边框
  ///
  /// 适用于：可点击卡片、悬浮卡片、重要内容区域
  factory BaseCard.elevated({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? borderRadius,
    Color? backgroundColor,
    VoidCallback? onTap,
    bool enableScaleAnimation = true,
    bool showBorder = false,
  }) {
    return BaseCard(
      key: key,
      padding: padding,
      margin: margin,
      showBorder: showBorder,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: adaptive.Adaptive.w(8),
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: adaptive.Adaptive.w(16),
          offset: const Offset(0, 4),
        ),
      ],
      onTap: onTap,
      enableScaleAnimation: enableScaleAnimation,
      child: child,
    );
  }

  /// 实色背景卡片——自定义背景色 + 无边框
  ///
  /// 适用于：强调区域、品牌色背景、状态提示
  factory BaseCard.filled({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    required Color backgroundColor,
    double? borderRadius,
    VoidCallback? onTap,
    bool enableScaleAnimation = false,
  }) {
    return BaseCard(
      key: key,
      padding: padding,
      margin: margin,
      showBorder: false,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      boxShadow: null,
      onTap: onTap,
      enableScaleAnimation: enableScaleAnimation,
      child: child,
    );
  }

  // ==================== 构建逻辑 ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surface;
    final effectiveBorderRadius = borderRadius ?? AppRadius.card;
    final effectiveBoxShadow =
        boxShadow ??
        (showBorder
            ? null // 描边模式默认无阴影
            : [
                // 非描边模式给轻微阴影以区分层次
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: adaptive.Adaptive.w(6),
                  offset: const Offset(0, 1),
                ),
              ]);

    Widget card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        border: showBorder
            ? Border.all(color: theme.colorScheme.outlineVariant, width: 0.5)
            : null,
        boxShadow: effectiveBoxShadow,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );

    // 包装点击效果
    if (onTap != null) {
      card = _ClickableWrapper(
        onTap: onTap!,
        borderRadius: effectiveBorderRadius,
        enableScaleAnimation: enableScaleAnimation,
        child: card,
      );
    }

    return card;
  }
}

/// 可点击包装器——统一处理点击反馈
class _ClickableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final bool enableScaleAnimation;

  const _ClickableWidget({
    required this.child,
    required this.onTap,
    required this.borderRadius,
    required this.enableScaleAnimation,
  });

  @override
  State<_ClickableWidget> createState() => _ClickableWidgetState();
}

class _ClickableWidgetState extends State<_ClickableWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enableScaleAnimation) _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enableScaleAnimation) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.enableScaleAnimation) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: widget.enableScaleAnimation
            ? _scaleAnimation
            : AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enableScaleAnimation ? _scaleAnimation.value : 1.0,
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: AppColors.primaryBrand.withValues(alpha: 0.08),
            highlightColor: AppColors.primaryBrand.withValues(alpha: 0.04),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// 兼容性别名（保持向后兼容）
typedef _ClickableWrapper = _ClickableWidget;

/// 带标题的卡片组件
///
/// 在 BaseCard 基础上增加标题行，适用于设置分组、统计面板等场景。
///
/// 使用示例：
/// ```dart
/// TitledCard(
///   title: '学习统计',
///   subtitle: '本周数据',
///   leadingIcon: Icons.bar_chart,
///   child: Text('统计内容'),
/// )
/// ```
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

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 是否显示边框
  final bool showBorder;

  const TitledCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.actions,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      padding: padding,
      margin: margin,
      showBorder: showBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              if (leadingIcon != null)
                Icon(
                  leadingIcon,
                  size: adaptive.Adaptive.icon(20),
                  color: AppColors.textSecondary,
                ),

              if (leadingIcon != null) SizedBox(width: AppSpacing.sm),

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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
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
