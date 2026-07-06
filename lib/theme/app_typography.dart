import 'package:flutter/material.dart';
import '../utils/adaptive.dart';

/// 字体系统 — VidLang 设计升级 v3.0
///
/// 五级字号体系（iPhone 基准值）：
/// - hero    32.0  w700  letterSpacing: -1.0%
/// - title   24.0  w700  letterSpacing: -0.5%
/// - heading 20.0  w600
/// - body    16.0  w400
/// - caption 13.0  w400
/// - micro   11.0  w500
///
/// iPad 下通过 Adaptive.sp 缩放。

// ═══════════════════════════════════════════════════════════════
// 运行时文本样式容器
// ═══════════════════════════════════════════════════════════════

class AppTextStylesData {
  final TextStyle hero;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle micro;

  const AppTextStylesData({
    required this.hero,
    required this.title,
    required this.heading,
    required this.body,
    required this.caption,
    required this.micro,
  });

  factory AppTextStylesData.of(BuildContext context) {
    return AppTextStylesData(
      hero: TextStyle(
        fontSize: Adaptive.sp(context, 32.0),
        fontWeight: FontWeight.w700,
        letterSpacing: 32.0 * -0.01,
        height: 1.2,
      ),
      title: TextStyle(
        fontSize: Adaptive.sp(context, 24.0),
        fontWeight: FontWeight.w700,
        letterSpacing: 24.0 * -0.005,
        height: 1.25,
      ),
      heading: TextStyle(
        fontSize: Adaptive.sp(context, 20.0),
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      body: TextStyle(
        fontSize: Adaptive.sp(context, 16.0),
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      caption: TextStyle(
        fontSize: Adaptive.sp(context, 13.0),
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      micro: TextStyle(
        fontSize: Adaptive.sp(context, 11.0),
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );
  }
}

extension AppTextStylesExtension on BuildContext {
  AppTextStylesData get textStyles => AppTextStylesData.of(this);
}

// ═══════════════════════════════════════════════════════════════
// 静态字体令牌（向后兼容）
// ═══════════════════════════════════════════════════════════════

enum FontWeightType {
  regular,
  medium,
  semiBold,
  bold,
}

class AppTypography {
  AppTypography();

  // ─── 字体家族 ──────────────────────────────────
  static const String fontFamilySans     = 'Inter';
  static const String fontFamilyMono     = 'SF Mono';
  static const String fontFamilyChinese  = 'PingFang SC';

  // ─── 字体大小 ──────────────────────────────────
  static const double fontSizeXSmall  = 12.0;
  static const double fontSizeSmall   = 14.0;
  static const double fontSizeBase    = 16.0;
  static const double fontSizeLarge   = 20.0;
  static const double fontSizeXLarge  = 25.0;
  static const double fontSize2XLarge = 31.0;
  static const double fontSize3XLarge = 39.0;
  static const double fontSize4XLarge = 49.0;
  static const double fontSize5XLarge = 61.0;

  static double getFontSize(String name) {
    switch (name) {
      case 'xs':   return fontSizeXSmall;
      case 'sm':   return fontSizeSmall;
      case 'base': return fontSizeBase;
      case 'lg':   return fontSizeLarge;
      case 'xl':   return fontSizeXLarge;
      case '2xl':  return fontSize2XLarge;
      case '3xl':  return fontSize3XLarge;
      case '4xl':  return fontSize4XLarge;
      case '5xl':  return fontSize5XLarge;
      default:     return fontSizeBase;
    }
  }

  // ─── 字体粗细 ──────────────────────────────────
  static const FontWeight fontWeightRegular  = FontWeight.w400;
  static const FontWeight fontWeightMedium   = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold     = FontWeight.w700;

  static FontWeight getFontWeight(FontWeightType type) {
    switch (type) {
      case FontWeightType.regular:  return fontWeightRegular;
      case FontWeightType.medium:   return fontWeightMedium;
      case FontWeightType.semiBold: return fontWeightSemiBold;
      case FontWeightType.bold:     return fontWeightBold;
    }
  }

  // ─── 行高 ──────────────────────────────────────
  static const double lineHeightTight   = 1.2;
  static const double lineHeightNormal  = 1.5;
  static const double lineHeightRelaxed = 1.75;

  // ─── 字间距 ────────────────────────────────────
  static const double letterSpacingTight  = -0.5;
  static const double letterSpacingNormal = 0;
  static const double letterSpacingWide   = 0.5;

  // ─── 常用文本样式（静态，向后兼容）─────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: fontSize2XLarge,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: 0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: fontSizeXLarge,
    fontWeight: fontWeightSemiBold,
    height: lineHeightTight,
    letterSpacing: 0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: fontWeightSemiBold,
    height: 1.3,
    letterSpacing: 0.2,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightRegular,
    height: lineHeightNormal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    height: lineHeightNormal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: fontWeightRegular,
    height: lineHeightNormal,
  );

  static const TextStyle label = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: fontWeightRegular,
    height: 1.4,
  );

  static const TextStyle button = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemiBold,
    height: 1.0,
  );

  static const TextStyle numeric = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    fontFamily: fontFamilyMono,
    height: lineHeightNormal,
  );
}
