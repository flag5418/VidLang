/// 设计令牌（Design Tokens）
/// 
/// 定义应用中所有的设计原子，包括颜色、字体、间距、圆角、阴影等。
/// 所有UI组件应使用此文件中定义的值，确保设计一致性和便于后期调整。
/// 
/// 使用方式：
/// ```dart
/// import 'package:vidlang/theme/design_tokens.dart';
/// 
/// // 使用颜色
/// DesignTokens.colors.primary
/// 
/// // 使用字体大小
/// DesignTokens.typography.fontSizeLarge
/// 
/// // 使用间距
/// DesignTokens.spacing.large
/// ```
library;

/// 颜色令牌
/// 
/// 定义应用中使用的所有颜色，包括：
/// - Primary colors（主色）
/// - Secondary colors（次要色）
/// - Neutral colors（中性色/灰阶色）
/// - Semantic colors（语义色：成功、警告、错误等）
/// - Surface colors（表面色：背景、卡片等）
/// 
/// 每种颜色都包含亮色和暗色版本
import 'package:flutter/material.dart';

import 'app_colors.dart';
/// 圆角令牌
/// 
/// 定义应用中使用的圆角值，包括：
/// - 小圆角（按钮、标签等）
/// - 中圆角（卡片、输入框等）
/// - 大圆角（模态框、底部sheet等）
/// - 全圆角（头像、圆形按钮等）
import 'app_radius.dart';
/// 阴影令牌
/// 
/// 定义应用中使用的阴影效果，包括：
/// - 无阴影
/// - 小阴影（轻微浮起）
/// - 中阴影（卡片悬浮）
/// - 大阴影（模态框等）
import 'app_shadows.dart';
/// 间距令牌
/// 
/// 基于8pt网格系统的间距规范，包括：
/// - 基础间距值（0-64）
/// - 语义化间距（xs, sm, md, lg, xl, xxl）
/// - 页面内边距
/// - 组件间距
import 'app_spacing.dart';
/// 字体令牌
/// 
/// 定义应用中使用的字体样式，包括：
/// - 字体家族
/// - 字体大小（基于1.25倍比例尺）
/// - 字体粗细
/// - 行高
import 'app_typography.dart';

/// 设计令牌汇总类
/// 
/// 将所有设计令牌汇总到一个类中，方便统一访问
class DesignTokens {
  DesignTokens._();

  /// 颜色令牌
  /// 
  /// 访问方式：DesignTokens.colors.primary
  // 颜色请直接使用 [AppColors] 静态成员

  /// 字体令牌
  /// 
  /// 访问方式：DesignTokens.typography.fontSizeLarge
  static final AppTypography typography = AppTypography();

  /// 间距令牌
  /// 
  /// 访问方式：DesignTokens.spacing.large
  static final AppSpacing spacing = AppSpacing();

  /// 圆角令牌
  /// 
  /// 访问方式：DesignTokens.radius.medium
  static final AppRadius radius = AppRadius();

  /// 阴影令牌
  /// 
  /// 访问方式：DesignTokens.shadows.card
  static final AppShadows shadows = AppShadows();

  /// 断点配置（响应式设计用）
  /// 
  /// | 名称 | 宽度 | 目标设备 |
  /// |------|------|---------|
  /// | xs | 0 | 小型手机 |
  /// | sm | 480px | 大型手机 |
  /// | md | 640px | 平板 |
  /// | lg | 768px | 小型笔记本 |
  /// | xl | 1024px | 桌面 |
  /// | 2xl | 1280px | 大屏幕 |
  static const Map<String, double> breakpoints = {
    'xs': 0,
    'sm': 480,
    'md': 640,
    'lg': 768,
    'xl': 1024,
    '2xl': 1280,
  };

  /// Z-index层级
  /// 
  /// 用于统一管理元素的堆叠顺序
  static const Map<String, int> zIndex = {
    'base': 0,
    'dropdown': 100,
    'sticky': 200,
    'fixed': 300,
    'modalBackdrop': 400,
    'modal': 500,
    'popover': 600,
    'tooltip': 700,
    'notification': 800,
  };

  /// 动画时长配置
  /// 
  /// 统一管理动画时长，保持一致的动效体验
  static const Map<String, Duration> animationDuration = {
    'fast': Duration(milliseconds: 150),
    'normal': Duration(milliseconds: 300),
    'slow': Duration(milliseconds: 500),
  };

  /// 动画缓动函数
  /// 
  /// 统一管理动画缓动曲线
  static const Map<String, Curve> animationCurve = {
    'default': Curves.easeInOut,
    'fast': Curves.easeOut,
    'smooth': Curves.easeInOutCubic,
    'bounce': Curves.elasticOut,
  };
}
