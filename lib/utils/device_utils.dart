/// 设备信息统一工具类
///
/// 集中管理设备类型判断、网格列数、间距等，避免各处散落判断逻辑。
///
/// iOS 平台通过 UIDevice.current.userInterfaceIdiom 精确判断；
/// 其他平台通过屏幕最短边 >= 600 判断。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidlang/services/ios_native_features.dart';

enum DeviceType { phone, tablet }

class DeviceUtils {
  DeviceUtils._();

  /// 缓存的设备类型（通过 [init] 初始化）
  static DeviceType? _cachedType;

  /// 初始化设备类型（建议在 main.dart 中调用一次）
  static Future<void> init() async {
    if (_cachedType != null) return;
    if (Platform.isIOS) {
      try {
        final idiom = await IosNativeFeatures.getDeviceIdiom();
        if (idiom == 'pad') {
          _cachedType = DeviceType.tablet;
          return;
        } else if (idiom == 'phone') {
          _cachedType = DeviceType.phone;
          return;
        }
      } catch (_) {}
    }
    // Android / macOS 或 iOS 原生调用失败时，留空让运行时通过屏幕尺寸判断
  }

  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    if (_cachedType != null) return _cachedType!;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600 ? DeviceType.tablet : DeviceType.phone;
  }

  /// 是否平板
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  /// 获取网格列数
  ///
  /// - phone: 2列
  /// - tablet: 3列
  static int getGridColumns(BuildContext context) {
    return isTablet(context) ? 3 : 2;
  }

  /// 获取网格间距
  static double getGridSpacing(BuildContext context) {
    return isTablet(context) ? 16.0 : 12.0;
  }

  /// 获取页面水平内边距
  static double getPagePadding(BuildContext context) {
    return isTablet(context) ? 24.0 : 16.0;
  }
}
