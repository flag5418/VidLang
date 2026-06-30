/// 学习难度设置 Provider
///
/// 五个难度等级，影响 AI 对话提问风格和测试出题难度。
/// 使用 SettingsService 持久化到 config 表（按用户隔离）。
///
/// 改进说明：
/// - 从 SharedPreferences 迁移到 SettingsService（config 表）
/// - 支持多用户隔离，每个用户可独立设置难度
/// - 应用重启后自动恢复上次的难度选择
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/services/settings_service.dart';

/// 学习难度等级
enum DifficultyLevel {
  beginner,
  elementary,
  intermediate,
  advanced,
  professional;

  /// 显示名称
  String get label {
    switch (this) {
      case DifficultyLevel.beginner:
        return '入门';
      case DifficultyLevel.elementary:
        return '初级';
      case DifficultyLevel.intermediate:
        return '中级';
      case DifficultyLevel.advanced:
        return '高级';
      case DifficultyLevel.professional:
        return '专业';
    }
  }

  /// 简短描述
  String get description {
    switch (this) {
      case DifficultyLevel.beginner:
        return '简单词汇，慢速，大量提示';
      case DifficultyLevel.elementary:
        return '基础句型，日常话题';
      case DifficultyLevel.intermediate:
        return '正常语速，适中复杂度';
      case DifficultyLevel.advanced:
        return '复杂句型，抽象话题';
      case DifficultyLevel.professional:
        return '学术/专业英语';
    }
  }

  /// 对应图标
  IconData get icon {
    switch (this) {
      case DifficultyLevel.beginner:
        return Icons.looks_one;
      case DifficultyLevel.elementary:
        return Icons.looks_two;
      case DifficultyLevel.intermediate:
        return Icons.looks_3;
      case DifficultyLevel.advanced:
        return Icons.looks_4;
      case DifficultyLevel.professional:
        return Icons.looks_5;
    }
  }

  /// 传给后端的难度标识（英文）
  String get code => name;

  /// 从字符串解析为 DifficultyLevel
  static DifficultyLevel fromString(String value) {
    return DifficultyLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DifficultyLevel.intermediate,
    );
  }
}

/// 难度设置 Notifier
///
/// 现在使用 SettingsService 持久化，支持多用户隔离。
class DifficultyNotifier extends StateNotifier<DifficultyLevel> {
  DifficultyNotifier() : super(DifficultyLevel.intermediate) {
    _load(); // 初始化时从 config 表加载
  }

  /// 从 config 表加载难度设置（按当前用户）
  Future<void> _load() async {
    try {
      final value = await SettingsService.getDifficultyLevel();
      state = DifficultyLevel.fromString(value);
    } catch (_) {
      // 加载失败时使用默认值（intermediate）
    }
  }

  /// 设置难度并持久化到 config 表（按用户隔离）
  Future<void> setLevel(DifficultyLevel level) async {
    state = level;
    await SettingsService.setDifficultyLevel(level.name); // 按用户隔离存储
  }
}

/// 难度设置 Provider
final difficultyProvider = StateNotifierProvider<DifficultyNotifier, DifficultyLevel>(
  (ref) => DifficultyNotifier(),
);
