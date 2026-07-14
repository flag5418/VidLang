import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 空状态组件——居中图标 + 标题 + 描述 + 可选操作按钮。
///
/// 图标 48pt，线条风格 Icons，颜色 textWeak（#C7C7CC）。
/// 标题 16sp（body），描述 13sp（caption）。
/// 按钮使用 Outlined 样式，品牌色描边。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: adaptive.Adaptive.h(context, 40),
          horizontal: adaptive.Adaptive.w(context, 32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: adaptive.Adaptive.icon(context, 48),
              color: colors.textWeak,
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 16)),
            Text(
              title,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 16),
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              SizedBox(height: adaptive.Adaptive.h(context, 8)),
              Text(
                description!,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 13),
                  fontWeight: FontWeight.w400,
                  color: colors.textWeak,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: adaptive.Adaptive.h(context, 20)),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.primary),
                  foregroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
