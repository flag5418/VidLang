import 'package:flutter/material.dart';

/// 圆角系统
/// 
/// 定义应用中使用的圆角值，保持一致的圆角风格。
/// 
/// 圆角风格（参考多邻国/现代风格）：
/// | 名称 | 值 | 用途 |
/// |------|-----|------|
/// | none | 0px | 无圆角（特殊用途） |
/// | xs | 4px | 小圆角 |
/// | sm | 8px | 标签、徽章 |
/// | md | 12px | 按钮、输入框 |
/// | lg | 16px | 卡片、弹窗 |
/// | xl | 24px | 大卡片 |
/// | 2xl | 32px | 模态框 |
/// | full | 9999px | 全圆（头像、圆形按钮） |
/// 
/// 使用方式：
/// ```dart
/// import 'package:vidlang/theme/design_tokens.dart';
/// 
/// Container(
///   decoration: BoxDecoration(
///     borderRadius: BorderRadius.circular(DesignTokens.radius.medium),
///   ),
/// )
/// ```

/// 应用圆角类
/// 
/// 包含所有圆角令牌
class AppRadius {
  AppRadius();

  // ============================================================
  // 基础圆角值
  // ============================================================
  
  /// 无圆角 - 0px
  /// 
  /// 用于：分割线、特殊布局
  static const double none = 0;
  
  /// 超小圆角 - 4px
  /// 
  /// 用于：标签、小徽章
  static const double xs = 4;
  
  /// 小圆角 - 8px
  /// 
  /// 用于：小按钮、标签、徽章
  static const double sm = 8;
  
  /// 中圆角 - 12px
  /// 
  /// 用于：按钮、输入框、卡片
  static const double md = 12;
  
  /// 大圆角 - 16px
  /// 
  /// 用于：大卡片、播放器
  static const double lg = 16;
  
  /// 超大圆角 - 24px
  /// 
  /// 用于：底部弹窗
  static const double xl = 24;
  
  /// 2倍超大圆角 - 32px
  /// 
  /// 用于：模态框、大容器
  static const double xxl = 32;
  
  /// 全圆 - 9999px
  /// 
  /// 用于：头像、圆形按钮
  static const double full = 9999;

  /// 获取圆角值
  /// 
  /// [name] 圆角名称：none, xs, sm, md, lg, xl, xxl, full
  static double getRadius(String name) {
    switch (name) {
      case 'none':
        return none;
      case 'xs':
        return xs;
      case 'sm':
        return sm;
      case 'md':
        return md;
      case 'lg':
        return lg;
      case 'xl':
        return xl;
      case 'xxl':
        return xxl;
      case 'full':
        return full;
      default:
        return md;
    }
  }

  // ============================================================
  // 组件特定圆角
  // ============================================================
  
  /// 按钮圆角
  static const double button = md;
  
  /// 按钮圆角（大）
  static const double buttonLarge = lg;
  
  /// 按钮圆角（小）
  static const double buttonSmall = sm;
  
  /// 输入框圆角
  static const double input = md;
  
  /// 卡片圆角
  static const double card = lg;
  
  /// 页面圆角
  static const double page = lg;
  
  /// 底部弹窗圆角
  static const double bottomSheet = xl;
  
  /// 模态框圆角
  static const double modal = xxl;
  
  /// 头像圆角
  static const double avatar = full;
  
  /// 标签圆角
  static const double tag = sm;
  
  /// 徽章圆角
  static const double badge = sm;
  
  /// 进度条圆角
  static const double progress = full;

  // ============================================================
  // BorderRadius便捷构造
  // ============================================================
  
  /// 获取所有方向相同的圆角
  static BorderRadius all(String name) {
    return BorderRadius.all(Radius.circular(getRadius(name)));
  }
  
  /// 获取水平方向的圆角（左右相同，上下为0）
  static BorderRadius horizontal(String name) {
    final radius = getRadius(name);
    return BorderRadius.horizontal(
      left: Radius.circular(radius),
      right: Radius.circular(radius),
    );
  }
  
  /// 获取垂直方向的圆角（上下相同，左右为0）
  static BorderRadius vertical(String name) {
    final radius = getRadius(name);
    return BorderRadius.vertical(
      top: Radius.circular(radius),
      bottom: Radius.circular(radius),
    );
  }
  
  /// 获取左上角圆角
  static BorderRadius topLeft(String name) {
    return BorderRadius.only(topLeft: Radius.circular(getRadius(name)));
  }
  
  /// 获取右上角圆角
  static BorderRadius topRight(String name) {
    return BorderRadius.only(topRight: Radius.circular(getRadius(name)));
  }
  
  /// 获取左下角圆角
  static BorderRadius bottomLeft(String name) {
    return BorderRadius.only(bottomLeft: Radius.circular(getRadius(name)));
  }
  
  /// 获取右下角圆角
  static BorderRadius bottomRight(String name) {
    return BorderRadius.only(bottomRight: Radius.circular(getRadius(name)));
  }
  
  /// 获取顶部圆角（左右相同）
  static BorderRadius top(String name) {
    final radius = getRadius(name);
    return BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );
  }
  
  /// 获取底部圆角（左右相同）
  static BorderRadius bottom(String name) {
    final radius = getRadius(name);
    return BorderRadius.only(
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );
  }
}
