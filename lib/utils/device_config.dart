/// 设备配置工具
///
/// 负责：
/// 1. 提供各设备类型对应的 ScreenUtil designSize（用于 ScreenUtilInit）
/// 2. 提供 iPad UI 适配常量
///
/// ⚠️ 设备类型检测由 main.dart _loadDeviceType() → DeviceInfoService 统一负责，
///    结果写入 AppGlobals.deviceType，本类不再包含设备检测逻辑。
library;

import 'package:flutter/widgets.dart';
import 'package:vidlang/models/device_type.dart';

class DeviceConfig {
  DeviceConfig._();

  // ============================================================
  // 设计稿基准尺寸（用于 ScreenUtilInit）
  // ============================================================

  /// iPhone 设计稿基准尺寸（iPhone 14 Pro Max 逻辑像素）
  static const Size iphoneDesignSize = Size(393, 852);

  /// iPad 设计稿基准尺寸（iPad Pro 13-inch M5，逻辑像素）
  static const Size ipadDesignSize = Size(834, 1194);

  /// 获取当前设备类型对应的 ScreenUtil designSize
  ///
  /// 在 main.dart 的 ScreenUtilInit 中调用，根据 AppGlobals.deviceType 选择设计尺寸
  static Size getDesignSize(AppDeviceType? deviceType) {
    final type = deviceType ?? AppDeviceType.iphone;
    switch (type) {
      case AppDeviceType.iphone:
        return iphoneDesignSize;
      case AppDeviceType.ipad:
        return ipadDesignSize;
    }
  }

  // ============================================================
  // iPad UI 适配常量
  // ============================================================

  /// iPad 网格列数
  static const int ipadGridColumns = 4;

  /// iPad 页面水平内边距
  static const double ipadPagePadding = 40;

  /// iPad 最小内容宽度（用于判断是否展示 tablet 布局）
  static const double ipadMinWidth = 600;
}
