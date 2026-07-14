/// 通用加载状态组件（TDesign 规范）
///
/// 使用 [TDLoading] 替代原生 [CircularProgressIndicator]，
/// 统一项目加载状态样式，支持文字提示。
///
/// 使用示例：
/// ```dart
/// LoadingWidget(message: '加载中...')
/// LoadingWidget() // 无文字的纯加载动画
/// ```
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/app_colors.dart';

class LoadingWidget extends StatelessWidget {
  /// 加载提示文字（如已设置，TDLoading 会自动垂直排列图标和文字）
  final String? message;

  /// 加载指示器尺寸（映射到 TDLoadingSize）
  final double? size;

  /// 自定义颜色（默认使用主题品牌色）
  final Color? color;

  const LoadingWidget({super.key, this.message, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    // ✅ TDesign 规范：使用 TDLoading 替代 CircularProgressIndicator
    return Center(
      child: TDLoading(
        size: _mapSize(size),
        icon: TDLoadingIcon.circle,
        iconColor: color ?? context.colors.primary,
        text: message,
        textColor: context.colors.textWeak,
        axis: Axis.vertical,
      ),
    );
  }

  /// 将自定义尺寸映射为 TDLoadingSize
  TDLoadingSize _mapSize(double? customSize) {
    if (customSize == null) return TDLoadingSize.medium;
    if (customSize <= 24) return TDLoadingSize.small;
    if (customSize <= 48) return TDLoadingSize.medium;
    return TDLoadingSize.large;
  }
}
