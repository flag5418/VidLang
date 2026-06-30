/// 主题模式管理 Provider
///
/// 功能：
/// 1. 管理应用主题模式（亮色/暗色/跟随系统）
/// 2. 使用 SettingsService 持久化到 config 表（按用户隔离）
/// 3. 提供 Riverpod 状态管理接口
///
/// 改进说明：
/// - 从 SharedPreferences 迁移到 SettingsService（config 表）
/// - 支持多用户隔离，每个用户可独立设置主题
/// - 应用重启后自动恢复上次的主题选择
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/services/settings_service.dart';

/// 主题模式枚举
enum AppThemeMode {
  light,
  dark,
  system;

  /// 转换为 Flutter 内置 ThemeMode
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 显示名称
  String get label {
    switch (this) {
      case AppThemeMode.light:
        return '白天模式';
      case AppThemeMode.dark:
        return '夜间模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  /// 对应图标
  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  /// 从字符串解析为 AppThemeMode
  static AppThemeMode fromString(String value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

/// 主题模式 Notifier
///
/// 现在使用 SettingsService 持久化，支持多用户隔离。
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system) {
    _load(); // 初始化时从 config 表加载
  }

  /// 从 config 表加载主题模式（按当前用户）
  Future<void> _load() async {
    try {
      final value = await SettingsService.getThemeMode();
      state = AppThemeMode.fromString(value);
    } catch (_) {
      // 加载失败时使用默认值（system）
    }
  }

  /// 设置主题模式并持久化到 config 表
  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await SettingsService.setThemeMode(mode.name); // 按用户隔离存储
  }
}

/// 主题模式 Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>(
  (ref) => ThemeModeNotifier(),
);
