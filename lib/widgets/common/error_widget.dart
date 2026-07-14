/// 通用错误状态组件（TDesign 规范）
///
/// 使用 [TDButton] 替代原生 [ElevatedButton]，
/// 统一项目错误展示样式，支持重试操作。
///
/// 使用示例：
/// ```dart
/// ErrorDisplayWidget(
///   error: '网络连接失败',
///   onRetry: () => ref.read(provider.notifier).loadData(),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart';

class ErrorDisplayWidget extends StatelessWidget {
  /// 错误信息文案
  final String error;
  
  /// 重试回调
  final VoidCallback? onRetry;
  
  /// 错误标题（默认"出错了"）
  final String? title;
  
  /// 是否显示重试按钮（默认 true）
  final bool showRetry;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Adaptive.w(context, 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ TDesign 规范：使用主题色图标
            Icon(
              AppIcons.error,
              size: Adaptive.sp(context, 64),
              color: context.colors.error,
            ),
            SizedBox(height: Adaptive.h(context, 16)),
            Text(
              title ?? '出错了',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 18),
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: Adaptive.h(context, 8)),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 14),
                color: context.colors.textWeak,
                height: 1.4,
              ),
            ),
            if (showRetry && onRetry != null) ...[
              SizedBox(height: Adaptive.h(context, 24)),
              // ✅ TDesign 规范：使用 TDButton 替代 ElevatedButton
              TDButton(
                text: '重试',
                size: TDButtonSize.medium,
                type: TDButtonType.fill,
                theme: TDButtonTheme.primary,
                onTap: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
