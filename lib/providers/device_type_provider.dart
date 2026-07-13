/// 设备类型 Provider
///
/// 管理全局设备类型（iPhone / iPad），支持手动覆盖。
/// 启动时先读本地存储，无则检测并写入。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/services/device_info_service.dart';

const String _kDeviceTypeKey = 'device_type';

class DeviceTypeNotifier extends StateNotifier<AppDeviceType> {
  DeviceTypeNotifier() : super(AppDeviceType.iphone) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kDeviceTypeKey);
      
      if (stored != null && stored.isNotEmpty) {
        // 有存储值，直接使用
        state = AppDeviceType.values.firstWhere(
          (e) => e.name == stored,
          orElse: () => AppDeviceType.iphone,
        );
        debugPrint('[DeviceTypeProvider] Loaded from storage: $state');
      } else {
        // 无存储值，检测并写入
        final detected = await DeviceInfoService.instance.detectDeviceType();
        state = detected;
        await _save(detected);
        debugPrint('[DeviceTypeProvider] Detected and saved: $state');
      }
    } catch (e) {
      debugPrint('[DeviceTypeProvider] init failed: $e');
      state = AppDeviceType.iphone; // 失败默认手机
    }
  }

  /// 手动设置设备类型
  ///
  /// 立即写入 SharedPreferences 并触发 rebuild
  Future<void> set(AppDeviceType type) async {
    state = type;
    await _save(type);
    debugPrint('[DeviceTypeProvider] Set to: $type');
  }

  /// 手动设置设备类型 (别名，用于 UI 调用)
  Future<void> setDeviceType(AppDeviceType type) => set(type);

  /// 重置为自动检测
  Future<void> resetToAuto() async {
    final detected = await DeviceInfoService.instance.detectDeviceType();
    state = detected;
    await _save(detected);
    debugPrint('[DeviceTypeProvider] Reset to: $state');
  }

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
