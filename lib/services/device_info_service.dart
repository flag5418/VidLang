/// 设备信息服务
///
/// 负责检测设备类型：
/// - iOS: 使用 device_info_plus 获取 utsname.machine (100% 准确)
/// - Android: 使用 shortestSide >= 600 检测 (建议用户手动选择)
library;

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:vidlang/models/device_type.dart';

class DeviceInfoService {
  DeviceInfoService._();
  
  static final DeviceInfoService instance = DeviceInfoService._();
  
  /// 检测设备类型
  Future<AppDeviceType> detectDeviceType() async {
    if (kIsWeb) {
      return AppDeviceType.iphone; // Web 默认手机
    }
    
    if (Platform.isIOS) {
      return _detectIOS();
    } else if (Platform.isAndroid) {
      return _detectAndroid();
    }
    
    return AppDeviceType.iphone; // 其他平台默认手机
  }
  
  /// iOS 设备检测 (使用 utsname.machine)
  ///
  /// iPad 标识符以 "iPad" 开头 (如 "iPad14,1", "iPad13,8")
  /// iPhone 标识符以 "iPhone" 开头 (如 "iPhone14,2", "iPhone15,4")
  /// 模拟器返回 "x86_64" 或 "arm64"，需要回退到屏幕尺寸检测
  Future<AppDeviceType> _detectIOS() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final machine = iosInfo.utsname.machine;
      
      debugPrint('[DeviceInfoService] iOS machine: $machine');
      
      // iPad 真机：标识符以 "iPad" 开头
      if (machine.startsWith('iPad')) {
        return AppDeviceType.ipad;
      }
      
      // iPhone 真机：标识符以 "iPhone" 开头
      if (machine.startsWith('iPhone')) {
        return AppDeviceType.iphone;
      }
      
      // 模拟器：machine 为 "x86_64" 或 "arm64"，回退到屏幕尺寸检测
      // 使用 WidgetsBinding 获取屏幕尺寸
      debugPrint('[DeviceInfoService] Simulator detected, using screen size fallback');
      return _detectByScreenSize();
    } catch (e) {
      debugPrint('[DeviceInfoService] iOS detection failed: $e');
      return AppDeviceType.iphone; // 检测失败默认手机
    }
  }
  
  /// 通过屏幕尺寸检测设备类型
  /// 
  /// shortestSide >= 600 视为 iPad
  AppDeviceType _detectByScreenSize() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
    debugPrint('[DeviceInfoService] Screen shortestSide: $shortestSide');
    return shortestSide >= 600 ? AppDeviceType.ipad : AppDeviceType.iphone;
  }
  
  /// Android 设备检测 (使用 shortestSide >= 600)
  ///
  /// 注意: Android 设备碎片化严重，此方法可能不准确
  /// 建议用户在设置中手动选择设备类型
  Future<AppDeviceType> _detectAndroid() async {
    // Android 无法通过 API 准确判断设备类型
    // 返回默认值，由用户在设置中手动选择
    return AppDeviceType.iphone;
  }
  
  /// 获取设备信息 (用于调试)
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (kIsWeb) {
      return {'platform': 'web'};
    }
    
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'machine': iosInfo.utsname.machine,
        'name': iosInfo.name,
        'model': iosInfo.model,
        'systemVersion': iosInfo.systemVersion,
      };
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'product': androidInfo.product,
        'display': androidInfo.display,
      };
    }
    
    return {'platform': 'unknown'};
  }
}
