/// 主题模式管理 Provider
///
/// 功能：
/// 1. 管理应用主题模式（亮色/暗色/跟随系统）
/// 2. 使用 SharedPreferences 持久化用户选择
/// 3. 提供 Riverpod 状态管理接口
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

/// 持久化存储 key
const String _themeModeKey = 'app_theme_mode';

/// 主题模式 Notifier
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system) {
    _load();
  }

  /// 从本地存储加载主题模式
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    if (value != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppThemeMode.system,
      );
    }
  }

  /// 设置主题模式并持久化
  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

/// 主题模式 Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>(
  (ref) => ThemeModeNotifier(),
);
