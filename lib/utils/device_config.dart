/// 设备类型检测与配置工具
///
/// 负责：
/// 1. 启动时检测当前设备类型（iOS 自动检测，可被 Provider 覆盖）
/// 2. 提供 iPad Pro 13-inch M5 的设计尺寸常量
/// 3. 提供各设备类型对应的 ScreenUtil designSize
library;

import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:vidlang/models/device_type.dart';

class DeviceConfig {
  DeviceConfig._();

  // ============================================================
  // 设备类型常量
  // ============================================================

  /// iPad Pro 13-inch M5 物理分辨率（横屏）
  static const Size ipadPhysicalSize = Size(2752, 2048);

  /// iPad Pro 13-inch M5 物理分辨率（竖屏）
  static const Size ipadPortraitSize = Size(2048, 2752);

  /// iPhone 设计稿基准尺寸（已有配置）
  static const Size iphoneDesignSize = Size(393, 852);

  /// iPad 设计稿基准尺寸（iPad Pro 13-inch M5，按逻辑像素）
  static const Size ipadDesignSize = Size(834, 1194);

  // ============================================================
  // 设备检测（仅限启动时 / 非 BuildContext 场景使用）
  // ============================================================
  // ⚠️ 正常 UI 代码请使用 deviceTypeProvider 或 isIPad(context)
  // 以下方法仅在无法获取 BuildContext 时使用（如 ScreenUtil 初始化）

  /// 根据屏幕尺寸检测设备类型
  ///
  /// ⚠️ 仅用于启动时 ScreenUtil 初始化等非 BuildContext 场景。
  /// UI 层请使用 deviceTypeProvider 或 isIPad(context)。
  static AppDeviceType detectFromSize(Size size) {
    final shortestSide = size.shortestSide;
    if (shortestSide >= 600) {
      return AppDeviceType.ipad;
    }
    return AppDeviceType.iphone;
  }

  /// 从 BuildContext 检测设备类型
  ///
  /// ⚠️ 优先使用 isIPad(context) 或 ref.watch(deviceTypeProvider)
  static AppDeviceType detectFromContext(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return detectFromSize(size);
  }

  /// 检测是否为 iOS 平台
  static bool get isIOS => Platform.isIOS;

  /// 检测是否为 macOS 平台（开发调试用）
  static bool get isMacOS => Platform.isMacOS;

  // ============================================================
  // ScreenUtil 配置
  // ============================================================

  /// 获取当前设备类型对应的 ScreenUtil designSize
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
  // UI 适配常量
  // ============================================================

  /// iPad 网格列数
  static const int ipadGridColumns = 4;

  /// iPad 页面内边距
  static const double ipadPagePadding = 40;

  /// iPad 最小内容宽度（用于判断是否展示 tablet 布局）
  static const double ipadMinWidth = 600;
}
