import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Plugin-local adaptive utilities
// ═══════════════════════════════════════════════════════════════
// This is a minimal version of the adaptive utilities from the main app.
// It detects iPad and applies scale factors without requiring ScreenUtil.
//
// Note: On iPhone, raw values (logical pixels) are returned.
// On iPad, values are scaled by the factor but NOT converted by ScreenUtil
// since the plugin doesn't have access to the app's ScreenUtil initialization.
// The Font class expects values in logical pixels, so we return scaled logical pixels.

/// 判断当前设备是否为 iPad（短边 >= 600pt）
bool isIPad(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// iPad 缩放系数
class DeviceScale {
  DeviceScale._();

  static const Map<String, double> _scales = {
    'font': 1.38,
    'width': 1.30,
    'height': 1.30,
    'radius': 1.20,
    'icon': 1.28,
  };

  static double of(String type) => _scales[type] ?? 1.0;
}

/// 自适应尺寸工具类
///
/// iPhone：返回原始值（逻辑像素）
/// iPad：返回缩放后的逻辑像素值（value × scale）
///
/// 注意：此工具类不依赖 ScreenUtil，返回值为逻辑像素。
/// Font 类等组件期望接收逻辑像素值。
class Adaptive {
  Adaptive._();

  /// 统一缩放逻辑（宽度/高度/间距）
  static double _scale(BuildContext context, num value, String type) {
    if (isIPad(context)) {
      return value.toDouble() * DeviceScale.of(type);
    }
    return value.toDouble();
  }

  /// 字体大小适配
  ///
  /// iPhone：返回原始值（逻辑像素）
  /// iPad：value × font系数（逻辑像素）
  static double sp(BuildContext context, num value) =>
      _scale(context, value, 'font');

  /// 水平尺寸适配（宽度）
  static double w(BuildContext context, num value) =>
      _scale(context, value, 'width');

  /// 垂直尺寸适配（高度）
  static double h(BuildContext context, num value) =>
      _scale(context, value, 'height');

  /// 圆角半径适配
  static double r(BuildContext context, num value) =>
      _scale(context, value, 'radius');

  /// 图标尺寸适配
  static double icon(BuildContext context, num value) =>
      _scale(context, value, 'icon');
}

// ═══════════════════════════════════════════════════════════════
// BuildContext 扩展
// ═══════════════════════════════════════════════════════════════

extension AdaptiveContext on BuildContext {
  /// 文字尺寸（font scale）
  double ts(num value) => Adaptive.sp(this, value);

  /// 通用尺寸（width/height scale）
  double s(num value) => Adaptive.w(this, value);

  /// 圆角尺寸（radius scale）
  double rs(num value) => Adaptive.r(this, value);

  /// 图标尺寸（icon scale）
  double is_(num value) => Adaptive.icon(this, value);

  /// 是否为 iPad 设备
  bool get ipad => isIPad(this);

  /// 是否为 iPhone 设备
  bool get iphone => !isIPad(this);
}
