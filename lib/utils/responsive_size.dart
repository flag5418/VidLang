/// 全局响应式尺寸工具
///
/// 统一控制 iPhone 和 iPad 下的图标、按钮、间距等尺寸。
/// 参考 deepenglish_pad 的设计：sp（字号）、.w（宽度比例）、.h（高度比例）
///
/// iPad 缩放策略：相对于 iPhone 采用 1.4–1.6x 的激进放大比例，
/// 确保大屏幕上的图标和按钮视觉上足够大气、易于点击。
library;

import 'package:flutter/material.dart';

class ResponsiveSize {
  ResponsiveSize._();

  /// 判断是否为平板（>= 600px）
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  /// 判断是否为平板（根据宽度）
  static bool isTabletByWidth(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  /// 获取屏幕宽度
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;

  /// 获取屏幕高度
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  /// 图标尺寸：iPad 34, iPhone 22（~1.55x）
  static double icon(BuildContext context) => isTablet(context) ? 34 : 22;

  /// 工具栏按钮尺寸：iPad 56, iPhone 40（1.4x）
  static double toolbarBtn(BuildContext context) => isTablet(context) ? 56 : 40;

  /// 页面水平内边距：iPad 24, iPhone 14
  static double pagePadding(BuildContext context) => isTablet(context) ? 24 : 14;

  /// 底部栏按钮尺寸：iPad 62, iPhone 44（~1.41x）
  static double bottomBtn(BuildContext context) => isTablet(context) ? 62 : 44;

  /// 底部栏图标尺寸：iPad 38, iPhone 26（~1.46x）
  static double bottomIcon(BuildContext context) => isTablet(context) ? 38 : 26;

  /// 字体缩放：iPad 1.35x，iPhone 1.0x
  static double fontSize(BuildContext context, double size) => isTablet(context) ? size * 1.35 : size;

  /// 宽度百分比（类似参考代码的 .w）
  static double wp(BuildContext context, double percent) => screenWidth(context) * percent / 100;

  /// 高度百分比（类似参考代码的 .h）
  static double hp(BuildContext context, double percent) => screenHeight(context) * percent / 100;

  /// 胶囊按钮高度：iPad 52, iPhone 34（~1.53x）
  static double pillHeight(BuildContext context) => isTablet(context) ? 52 : 34;

  /// 卡片圆角：iPad 18, iPhone 10
  static double cardRadius(BuildContext context) => isTablet(context) ? 18 : 10;

  /// 底部导航栏图标尺寸：iPad 36, iPhone 24（1.5x）
  static double navIcon(BuildContext context) => isTablet(context) ? 36 : 24;

  /// 底部导航栏字号：iPad 14, iPhone 11
  static double navFontSize(BuildContext context) => isTablet(context) ? 14 : 11;

  /// 播放器顶部按钮尺寸：iPad 56, iPhone 40（1.4x）
  static double playerTopBtn(BuildContext context) => isTablet(context) ? 56 : 40;

  /// 播放器顶部图标尺寸：iPad 32, iPhone 22（~1.45x）
  static double playerTopIcon(BuildContext context) => isTablet(context) ? 32 : 22;

  /// 播放器控制按钮尺寸：iPad 52, iPhone 34（~1.53x）
  static double playerCtrlBtn(BuildContext context) => isTablet(context) ? 52 : 34;

  /// 播放器控制图标尺寸：iPad 28, iPhone 18（~1.56x）
  static double playerCtrlIcon(BuildContext context) => isTablet(context) ? 28 : 18;

  /// 播放器功能文字按钮字号：iPad 16, iPhone 11（~1.45x）
  static double playerFeatureFontSize(BuildContext context) => isTablet(context) ? 16 : 11;

  /// 播放器时间字号：iPad 16, iPhone 10
  static double playerTimeFontSize(BuildContext context) => isTablet(context) ? 16 : 10;
}
