/// 阴影系统
/// 
/// 定义应用中使用的阴影效果，包括：
/// - 无阴影
/// - 小阴影（轻微浮起）
/// - 中阴影（卡片悬浮）
/// - 大阴影（模态框等）
/// 
/// 阴影结构：
/// - color: 阴影颜色（通常带透明度）
/// - blur: 模糊半径
/// - offset: 偏移量
/// - spread: 扩散范围
/// 
/// 使用方式：
/// ```dart
/// import 'package:vidlang/theme/design_tokens.dart';
/// 
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: DesignTokens.shadows.card,
///   ),
/// )
/// ```
library;

import 'package:flutter/material.dart';

/// 应用阴影类
/// 
/// 包含所有阴影令牌
class AppShadows {
  AppShadows();

  // ============================================================
  // 阴影定义
  // ============================================================
  
  /// 无阴影
  /// 
  /// 用于：需要扁平设计时
  static const List<BoxShadow> none = [];
  
  /// 超小阴影 - 轻微浮起效果
  /// 
  /// color: rgba(0, 0, 0, 0.05)
  /// blur: 4px
  /// offset: (0, 1)
  /// 用于：次要卡片、标签
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  
  /// 小阴影 - 轻微浮起效果
  /// 
  /// color: rgba(0, 0, 0, 0.08)
  /// blur: 6px
  /// offset: (0, 2)
  /// 用于：按钮、输入框
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
  
  /// 中阴影 - 卡片悬浮效果
  /// 
  /// color: rgba(0, 0, 0, 0.10)
  /// blur: 12px
  /// offset: (0, 4)
  /// 用于：卡片、弹窗
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  /// 大阴影 - 模态框效果
  /// 
  /// color: rgba(0, 0, 0, 0.15)
  /// blur: 24px
  /// offset: (0, 8)
  /// 用于：模态框、大卡片
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
  
  /// 超大阴影 - 强调效果
  /// 
  /// color: rgba(0, 0, 0, 0.20)
  /// blur: 48px
  /// offset: (0, 16)
  /// 用于：特殊模态框、浮层
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
  ];

  // ============================================================
  // 组件特定阴影
  // ============================================================
  
  /// 卡片阴影
  static const List<BoxShadow> card = md;
  
  /// 卡片悬浮阴影
  static const List<BoxShadow> cardHover = lg;
  
  /// 按钮阴影
  static const List<BoxShadow> button = sm;
  
  /// 按钮悬浮阴影
  static const List<BoxShadow> buttonHover = md;
  
  /// 输入框阴影
  static const List<BoxShadow> input = sm;
  
  /// 模态框阴影
  static const List<BoxShadow> modal = lg;
  
  /// 下拉菜单阴影
  static const List<BoxShadow> dropdown = md;
  
  /// 工具提示阴影
  static const List<BoxShadow> tooltip = sm;

  // ============================================================
  // 内阴影
  // ============================================================
  
  /// 内阴影（顶部）
  /// 
  /// 用于：输入框按下效果
  static const List<BoxShadow> innerTop = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: -2,
    ),
  ];
  
  /// 内阴影（底部）
  /// 
  /// 用于：凹陷效果
  static const List<BoxShadow> innerBottom = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, -2),
      spreadRadius: -2,
    ),
  ];

  // ============================================================
  // 获取阴影
  // ============================================================
  
  /// 获取阴影
  /// 
  /// [name] 阴影名称：none, xs, sm, md, lg, xl
  static List<BoxShadow> getShadow(String name) {
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
      default:
        return md;
    }
  }
}
