/// 全局响应式尺寸工具
///
/// 统一控制 iPhone 和 iPad 下的图标、按钮、间距等尺寸。
/// 参考 deepenglish_pad 的设计：sp（字号）、.w（宽度比例）、.h（高度比例）
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

  /// 图标尺寸：iPad 28, iPhone 22
  static double icon(BuildContext context) => isTablet(context) ? 28 : 22;

  /// 工具栏按钮尺寸：iPad 48, iPhone 40
  static double toolbarBtn(BuildContext context) => isTablet(context) ? 48 : 40;

  /// 页面水平内边距：iPad 20, iPhone 14
  static double pagePadding(BuildContext context) => isTablet(context) ? 20 : 14;

  /// 底部栏按钮尺寸：iPad 52, iPhone 44
  static double bottomBtn(BuildContext context) => isTablet(context) ? 52 : 44;

  /// 底部栏图标尺寸：iPad 32, iPhone 26
  static double bottomIcon(BuildContext context) => isTablet(context) ? 32 : 26;

  /// 字体缩放（字号用 sp，Flutter 自动适配）
  static double fontSize(BuildContext context, double size) => size;

  /// 宽度百分比（类似参考代码的 .w）
  static double wp(BuildContext context, double percent) => screenWidth(context) * percent / 100;

  /// 高度百分比（类似参考代码的 .h）
  static double hp(BuildContext context, double percent) => screenHeight(context) * percent / 100;

  /// 胶囊按钮高度：iPad 44, iPhone 34
  static double pillHeight(BuildContext context) => isTablet(context) ? 44 : 34;

  /// 卡片圆角：iPad 14, iPhone 10
  static double cardRadius(BuildContext context) => isTablet(context) ? 14 : 10;
}
