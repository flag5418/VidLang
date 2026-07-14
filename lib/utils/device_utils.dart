/// 设备信息工具类（已废弃）
///
/// DEPRECATED: 请使用新的设备类型系统：
/// - `lib/models/device_type.dart` - AppDeviceType 枚举
/// - `lib/providers/device_type_provider.dart` - DeviceTypeProvider
/// - `lib/utils/device_config.dart` - DeviceConfig 配置类
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/providers/device_type_provider.dart';
import 'package:vidlang/utils/device_config.dart';

class DeviceUtils {
  DeviceUtils._();

  /// 初始化（已废弃，由 DeviceTypeProvider 接管）
  // static Future<void> initialize() async {}

  /// 获取当前设备类型
  static AppDeviceType getDeviceType(WidgetRef ref) {
    return ref.read(deviceTypeProvider);
  }

  /// 网格列数 - 根据设备类型动态返回
  static int get gridColumns {
    return DeviceConfig.ipadGridColumns;
  }

  /// 网格间距
  static const double gridSpacing = 12.0;

  /// 页面水平内边距 - 根据设备类型返回
  static double get pagePadding {
    return 16.0;
  }
}
