/// 应用全局静态配置
///
/// 收敛高频使用的全局状态为静态变量，避免每次获取都需要：
/// - 传 BuildContext
/// - 解析 ProviderContainer
/// - 读 SharedPreferences
/// - 回退到屏幕尺寸检测
///
/// **包含的静态变量**：
/// - [deviceType]  — 设备类型（iPhone / iPad），启动时一次性设定
/// - [user]        — 当前登录用户，登录/登出时更新
/// - [subscriptionMode] — 订阅模式（free / premium），用户可切换
/// - [balance]     — 付费模式余额（元）
///
/// **使用方式**：
/// ```dart
/// // 读取（任意位置，无需 context）
/// final isPad = AppGlobals.deviceType.isTablet;
/// final user = AppGlobals.user;
/// final isPremium = AppGlobals.subscriptionMode == SubscriptionMode.premium;
///
/// // 更新（通过对应方法）
/// AppGlobals.updateDeviceType(AppDeviceType.ipad);
/// AppGlobals.updateUser(newUser);
/// AppGlobals.updateSubscriptionMode(SubscriptionMode.premium);
/// ```
library;

import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/providers/subscription_provider.dart';

/// 应用全局静态配置
class AppGlobals {
  AppGlobals._();

  // ════════════════════════════════════════════
  // ① 设备类型（启动时由 main.dart _loadDeviceType 设定）
  // ════════════════════════════════════════════

  /// 当前设备类型
  ///
  /// 启动时由 main.dart 的 _loadDeviceType() 检测并写入，
  /// 用户可在设置中手动切换（通过 DeviceTypeProvider.set()）。
  static AppDeviceType deviceType = AppDeviceType.iphone;

  /// 更新设备类型（用户手动切换时调用）
  static void updateDeviceType(AppDeviceType type) {
    deviceType = type;
  }

  // ════════════════════════════════════════════
  // ② 当前登录用户（登录/登出时更新）
  // ════════════════════════════════════════════

  /// 当前登录用户（未登录时为 null）
  static User? user;

  /// 更新当前用户（登录/切换用户/更新资料时调用）
  static void updateUser(User? newUser) {
    user = newUser;
  }

  /// 是否已登录
  static bool get isLoggedIn => user != null;

  // ════════════════════════════════════════════
  // ③ 订阅 / 计费模式（用户可切换，Android 强制 premium）
  // ════════════════════════════════════════════

  /// 当前订阅模式
  static SubscriptionMode subscriptionMode = SubscriptionMode.free;

  /// 付费模式余额（元）
  static double balance = 0.0;

  /// 是否为付费模式
  static bool get isPremium => subscriptionMode == SubscriptionMode.premium;

  /// 更新订阅模式（用户切换 free/premium 时调用）
  static void updateSubscriptionMode(SubscriptionMode mode) {
    subscriptionMode = mode;
  }

  /// 更新余额（从云端刷新后调用）
  static void updateBalance(double newBalance) {
    balance = newBalance;
  }

  // ════════════════════════════════════════════
  // ④ 便捷判断（组合条件）
  // ════════════════════════════════════════════

  /// 是否为大屏设备（iPad）
  static bool get isTablet => deviceType.isTablet;

  /// 是否为手机（iPhone）
  static bool get isPhone => deviceType.isPhone;

  /// 付费模式下是否有可用余额
  static bool hasBalance(double cost) => balance >= cost;
}
