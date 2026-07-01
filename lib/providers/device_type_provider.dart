/// 设备类型 Provider
///
/// 管理全局设备类型（iPhone / iPad），支持手动覆盖。
/// 启动时自动检测，用户可在设置中手动切换。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/utils/device_config.dart';

const String _kDeviceTypeKey = 'device_type_override';

class DeviceTypeNotifier extends StateNotifier<AppDeviceType> {
  DeviceTypeNotifier() : super(AppDeviceType.iphone) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final override = prefs.getString(_kDeviceTypeKey);
      if (override != null && override.isNotEmpty) {
        state = override == 'ipad' ? AppDeviceType.ipad : AppDeviceType.iphone;
      } else {
        state = _detectDefault();
        await _save(state);
      }
    } catch (e) {
      debugPrint('[DeviceTypeProvider] init failed: $e');
      state = _detectDefault();
    }
  }

  AppDeviceType _detectDefault() {
    return AppDeviceType.iphone;
  }

  Future<void> set(AppDeviceType type) async {
    state = type;
    await _save(type);
  }

  void updateFromContext(BuildContext context) {
    final detected = DeviceConfig.detectFromContext(context);
    if (detected != state) {
      state = detected;
      _save(detected);
    }
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

extension DeviceTypeExtension on WidgetRef {
  AppDeviceType get deviceType => watch(deviceTypeProvider);
  AppDeviceType get deviceTypeWithoutWatch => read(deviceTypeProvider);
}
