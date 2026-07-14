import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// Plugin-local adaptive utilities
// ═══════════════════════════════════════════════════════════════
// 直接从 SharedPreferences 读取设备类型，无回调机制

/// 设备类型枚举 (与主应用保持一致)
enum AppDeviceType {
  iphone,
  ipad;
  
  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
}

/// 判断当前设备是否为 iPad (使用缓存值，无缓存则回退到尺寸检测)
bool isIPad(BuildContext context) => Adaptive.getDeviceType(context).isTablet;

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
  
  // 缓存设备类型，避免重复读取 SharedPreferences
  static AppDeviceType? _cachedDeviceType;
  
  /// 从 SharedPreferences 读取设备类型
  ///
  /// 优先使用缓存，无缓存则读取存储
  static Future<AppDeviceType> _getDeviceTypeFromStorage() async {
    if (_cachedDeviceType != null) {
      return _cachedDeviceType!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('device_type');
      
      if (stored != null && stored.isNotEmpty) {
        _cachedDeviceType = AppDeviceType.values.firstWhere(
          (e) => e.name == stored,
          orElse: () => AppDeviceType.iphone,
        );
      } else {
        _cachedDeviceType = AppDeviceType.iphone; // 默认手机
      }
    } catch (e) {
      _cachedDeviceType = AppDeviceType.iphone; // 失败默认手机
    }
    
    return _cachedDeviceType!;
  }
  
  /// 同步获取设备类型 (用于 build 方法)
  ///
  /// 优先使用缓存，无缓存则使用屏幕尺寸检测
  static AppDeviceType getDeviceType(BuildContext context) {
    if (_cachedDeviceType != null) {
      return _cachedDeviceType!;
    }
    
    // 直接使用屏幕尺寸检测，避免递归调用
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600 ? AppDeviceType.ipad : AppDeviceType.iphone;
  }
  
  /// 初始化缓存 (应用启动时调用)
  static Future<void> initCache() async {
    await _getDeviceTypeFromStorage();
  }
  
  /// 更新缓存 (用户修改设备类型时调用)
  static void updateCache(AppDeviceType type) {
    _cachedDeviceType = type;
  }
  
  /// 统一缩放逻辑 (宽度/高度/间距)
  static double _scale(BuildContext context, num value, String type) {
    if (getDeviceType(context).isTablet) {
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
    return value.toDouble();
  }

  /// 字体大小适配
  static double sp(BuildContext context, num value) =>
      _scale(context, value, 'font');

  /// 水平尺寸适配 (宽度)
  static double w(BuildContext context, num value) =>
      _scale(context, value, 'width');

  /// 垂直尺寸适配 (高度)
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
  /// 文字尺寸 (font scale)
  double ts(num value) => Adaptive.sp(this, value);

  /// 通用尺寸 (width/height scale)
  double s(num value) => Adaptive.w(this, value);

  /// 垂直尺寸 (height scale)
  double h(num value) => Adaptive.h(this, value);

  /// 圆角尺寸 (radius scale)
  double rs(num value) => Adaptive.r(this, value);

  /// 图标尺寸 (icon scale)
  double is_(num value) => Adaptive.icon(this, value);

  /// 是否为 iPad 设备
  bool get ipad => Adaptive.getDeviceType(this).isTablet;

  /// 是否为 iPhone 设备
  bool get iphone => Adaptive.getDeviceType(this).isPhone;
}
