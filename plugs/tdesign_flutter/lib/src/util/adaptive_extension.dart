import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ═══════════════════════════════════════════════════════════════
// Plugin-local adaptive utilities
// ═══════════════════════════════════════════════════════════════
//
// 设备类型缓存由主应用 main.dart 在启动时通过 updateCache() 注入。
// 插件内部不读取 SharedPreferences、不做屏幕尺寸回退，
// 仅使用主应用传入的缓存值。

/// 设备类型枚举 (与主应用保持一致)
enum AppDeviceType {
  iphone,
  ipad;
  
  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
}

/// 判断当前设备是否为 iPad
///
/// ⚠️ 必须先调用 Adaptive.updateCache() 初始化缓存，否则默认返回 false
bool isIPad() => Adaptive.cachedDeviceType?.isTablet ?? false;

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
/// iPhone：返回原始值 (逻辑像素)
/// iPad：返回缩放后的逻辑像素值 (value × scale)
class Adaptive {
  Adaptive._();
  
  /// 设备类型缓存（由主应用启动时注入）
  static AppDeviceType? _cachedDeviceType;
  
  /// 获取当前缓存的设备类型（可能为 null，若尚未初始化）
  static AppDeviceType? get cachedDeviceType => _cachedDeviceType;
  
  /// 更新设备类型缓存（主应用启动时 / 用户切换时调用）
  ///
  /// [type] - 主应用的 AppDeviceType 值（通过 plugin_adaptive.AppDeviceType 映射）
  static void updateCache(AppDeviceType type) {
    _cachedDeviceType = type;
  }
  
  /// 统一缩放逻辑 (宽度/高度/间距)
  ///
  /// 若缓存尚未初始化，默认按 iPhone 处理（不缩放）
  static double _scale(num value, String type) {
    if (_cachedDeviceType?.isTablet != true) {
      return value.toDouble();
    }
    
    final scaled = value.toDouble() * DeviceScale.of(type);
    // 应用 ScreenUtil 映射，保持与主应用一致
    switch (type) {
      case 'font':
        return scaled.sp;
      case 'width':
        return scaled.w;
      case 'height':
        return scaled.h;
      case 'radius':
        return scaled.r;
      case 'icon':
        return scaled.sp;
      default:
        return scaled;
    }
  }

  /// 字体大小适配
  static double sp(num value) => _scale(value, 'font');

  /// 水平尺寸适配 (宽度)
  static double w(num value) => _scale(value, 'width');

  /// 垂直尺寸适配 (高度)
  static double h(num value) => _scale(value, 'height');

  /// 圆角半径适配
  static double r(num value) => _scale(value, 'radius');

  /// 图标尺寸适配
  static double icon(num value) => _scale(value, 'icon');
}

// ═══════════════════════════════════════════════════════════════
// BuildContext 扩展（保留兼容性，但不再需要 context 来判断设备类型）
// ═══════════════════════════════════════════════════════════════

extension AdaptiveContext on BuildContext {
  /// 文字尺寸 (font scale)
  double ts(num value) => Adaptive.sp(this);

  /// 通用尺寸 (width/height scale)
  double s(num value) => Adaptive.w(this);

  /// 垂直尺寸 (height scale)
  double h(num value) => Adaptive.h(this);

  /// 圆角尺寸 (radius scale)
  double rs(num value) => Adaptive.r(this);

  /// 图标尺寸 (icon scale)
  double is_(num value) => Adaptive.icon(this);

  /// 是否为 iPad 设备
  bool get ipad => isIPad();

  /// 是否为 iPhone 设备
  bool get iphone => !isIPad();
}
