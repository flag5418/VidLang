/// 设备类型 Provider
///
/// 管理全局设备类型（iPhone / iPad），支持手动覆盖。
///
/// **数据流向**：
/// 1. main.dart _loadDeviceType() → AppGlobals.deviceType → Provider 初始值
/// 2. 用户手动切换 → Provider.set() → AppGlobals.updateDeviceType() + SharedPreferences
/// 3. 任意位置读取 → AppGlobals.deviceType（静态变量，无需 context）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/utils/app_globals.dart';

const String _kDeviceTypeKey = 'device_type';

class DeviceTypeNotifier extends StateNotifier<AppDeviceType> {
  DeviceTypeNotifier() : super(AppGlobals.deviceType);

  /// 手动设置设备类型
  ///
  /// 同步更新：state → AppGlobals → SharedPreferences → 触发 UI rebuild
  Future<void> set(AppDeviceType type) async {
    state = type;
    AppGlobals.updateDeviceType(type);
    await _save(type);
    debugPrint('[DeviceTypeProvider] Set to: $type');
  }

  /// 手动设置设备类型 (别名，用于 UI 调用)
  Future<void> setDeviceType(AppDeviceType type) => set(type);

  Future<void> _save(AppDeviceType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDeviceTypeKey, type.name);
    } catch (e) {
      debugPrint('[DeviceTypeProvider] save failed: $e');
    }
  }
}

final deviceTypeProvider =
    StateNotifierProvider<DeviceTypeNotifier, AppDeviceType>(
  (ref) => DeviceTypeNotifier(),
);

/// 设备类型加载状态 (预留，当前始终为 false)
final deviceTypeLoadingProvider = StateProvider<bool>((ref) => false);

extension DeviceTypeExtension on WidgetRef {
  AppDeviceType get deviceType => watch(deviceTypeProvider);
  AppDeviceType get deviceTypeWithoutWatch => read(deviceTypeProvider);
}
