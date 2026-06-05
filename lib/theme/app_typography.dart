import 'package:flutter/material.dart';

/// 字体系统
/// 
/// 定义应用中使用的字体规范，基于1.25倍比例尺。
/// 
/// 字体大小比例（基于16px基础字号）：
/// | 名称 | 值 | 计算方式 |
/// |------|-----|---------|
/// | xs | 10px | 16 ÷ 1.25² |
/// | sm | 13px | 16 ÷ 1.25¹ |
/// | base | 16px | 基础 |
/// | lg | 20px | 16 × 1.25¹ |
/// | xl | 25px | 16 × 1.25² |
/// | 2xl | 31px | 16 × 1.25³ |
/// | 3xl | 39px | 16 × 1.25⁴ |
/// | 4xl | 49px | 16 × 1.25⁵ |
/// | 5xl | 61px | 16 × 1.25⁶ |
/// 
/// 使用方式：
/// ```dart
/// import 'package:vidlang/theme/design_tokens.dart';
/// 
/// Text('Hello', style: TextStyle(
///   fontSize: DesignTokens.typography.fontSizeLarge,
///   fontWeight: DesignTokens.typography.fontWeightSemiBold,
/// ));
/// ```

/// 字体粗细枚举
/// 
/// 对应FontWeight常用值
/// 
/// | 名称 | FontWeight值 | 用途 |
/// |------|-------------|------|
/// | regular | 400 | 正文 |
/// | medium | 500 | 强调 |
/// | semiBold | 600 | 标题 |
/// | bold | 700 | 重点 |
enum FontWeightType {
  regular,
  medium,
  semiBold,
  bold,
}

/// 应用字体类
/// 
/// 包含所有字体令牌
class AppTypography {
  AppTypography();

  // ============================================================
  // 字体家族
  // ============================================================
  
  /// 无衬线字体（用于正文和标题）
  /// 
  /// 优先使用系统字体，fallback到Inter
  static const String fontFamilySans = 'Inter';
  
  /// 等宽字体（用于代码和数字）
  static const String fontFamilyMono = 'SF Mono';
  
  /// 中文备选字体
  static const String fontFamilyChinese = 'PingFang SC';

  // ============================================================
  // 字体大小（基于1.25倍比例尺）
  // ============================================================
  
  /// 超小字体 - 10px
  /// 
  /// 用于：辅助说明、标签等
  static const double fontSizeXSmall = 10.0;
  
  /// 小字体 - 13px
  /// 
  /// 用于：次要文本、辅助信息等
  static const double fontSizeSmall = 13.0;
  
  /// 基础字体 - 16px
  /// 
  /// 用于：正文文本
  static const double fontSizeBase = 16.0;
  
  /// 大字体 - 20px
  /// 
  /// 用于：副标题、小标题等
  static const double fontSizeLarge = 20.0;
  
  /// 超大字体 - 25px
  /// 
  /// 用于：页面标题等
  static const double fontSizeXLarge = 25.0;
  
  /// 2倍超大字体 - 31px
  /// 
  /// 用于：主要标题
  static const double fontSize2XLarge = 31.0;
  
  /// 3倍超大字体 - 39px
  /// 
  /// 用于：大标题（较少使用）
  static const double fontSize3XLarge = 39.0;
  
  /// 4倍超大字体 - 49px
  /// 
  /// 用于：特殊展示
  static const double fontSize4XLarge = 49.0;
  
  /// 5倍超大字体 - 61px
  /// 
  /// 用于：Hero展示
  static const double fontSize5XLarge = 61.0;

  /// 获取字体大小（通过名称）
  /// 
  /// 方便动态获取字体大小
  /// 
  /// | 名称 | 值 |
  /// |------|-----|
  /// | 'xs' | 10px |
  /// | 'sm' | 13px |
  /// | 'base' | 16px |
  /// | 'lg' | 20px |
  /// | 'xl' | 25px |
  /// | '2xl' | 31px |
  /// | '3xl' | 39px |
  /// | '4xl' | 49px |
  /// | '5xl' | 61px |
  static double getFontSize(String name) {
    switch (name) {
      case 'xs':
        return fontSizeXSmall;
      case 'sm':
        return fontSizeSmall;
      case 'base':
        return fontSizeBase;
      case 'lg':
        return fontSizeLarge;
      case 'xl':
        return fontSizeXLarge;
      case '2xl':
        return fontSize2XLarge;
      case '3xl':
        return fontSize3XLarge;
      case '4xl':
        return fontSize4XLarge;
      case '5xl':
        return fontSize5XLarge;
      default:
        return fontSizeBase;
    }
  }

  // ============================================================
  // 字体粗细
  // ============================================================
  
  /// 常规字体 - FontWeight.w400
  static const FontWeight fontWeightRegular = FontWeight.w400;
  
  /// 中等字体 - FontWeight.w500
  static const FontWeight fontWeightMedium = FontWeight.w500;
  
  /// 半粗字体 - FontWeight.w600
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  
  /// 粗字体 - FontWeight.w700
  static const FontWeight fontWeightBold = FontWeight.w700;

  /// 获取字体粗细
  static FontWeight getFontWeight(FontWeightType type) {
    switch (type) {
      case FontWeightType.regular:
        return fontWeightRegular;
      case FontWeightType.medium:
        return fontWeightMedium;
      case FontWeightType.semiBold:
        return fontWeightSemiBold;
      case FontWeightType.bold:
        return fontWeightBold;
    }
  }

  // ============================================================
  // 行高
  // ============================================================
  
  /// 紧凑行高 - 1.2
  /// 
  /// 用于：标题
  static const double lineHeightTight = 1.2;
  
  /// 正常行高 - 1.5
  /// 
  /// 用于：正文
  static const double lineHeightNormal = 1.5;
  
  /// 宽松行高 - 1.75
  /// 
  /// 用于：正文（需要更多呼吸空间时）
  static const double lineHeightRelaxed = 1.75;

  // ============================================================
  // 字间距
  // ============================================================
  
  /// 紧凑字间距 - -0.5
  static const double letterSpacingTight = -0.5;
  
  /// 正常字间距 - 0
  static const double letterSpacingNormal = 0;
  
  /// 宽松字间距 - 0.5
  static const double letterSpacingWide = 0.5;

  // ============================================================
  // 常用文本样式
  // ============================================================
  
  /// 大标题样式
  /// 
  /// fontSize: 31px (2xl)
  /// fontWeight: 700 (bold)
  /// lineHeight: 1.2
  static const TextStyle headingLarge = TextStyle(
    fontSize: fontSize2XLarge,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
  );
  
  /// 中标题样式
  /// 
  /// fontSize: 25px (xl)
  /// fontWeight: 600 (semiBold)
  /// lineHeight: 1.2
  static const TextStyle headingMedium = TextStyle(
    fontSize: fontSizeXLarge,
    fontWeight: fontWeightSemiBold,
    height: lineHeightTight,
  );
  
  /// 小标题样式
  /// 
  /// fontSize: 20px (lg)
  /// fontWeight: 600 (semiBold)
  /// lineHeight: 1.3
  static const TextStyle headingSmall = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: fontWeightSemiBold,
    height: 1.3,
  );
  
  /// 正文样式
  /// 
  /// fontSize: 16px (base)
  /// fontWeight: 400 (regular)
  /// lineHeight: 1.5
  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightRegular,
    height: lineHeightNormal,
  );
  
  /// 正文样式（中等大小）
  /// 
  /// fontSize: 16px (base)
  /// fontWeight: 500 (medium)
  /// lineHeight: 1.5
  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    height: lineHeightNormal,
  );
  
  /// 小正文样式
  /// 
  /// fontSize: 13px (sm)
  /// fontWeight: 400 (regular)
  /// lineHeight: 1.5
  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: fontWeightRegular,
    height: lineHeightNormal,
  );
  
  /// 辅助文本样式
  /// 
  /// fontSize: 13px (sm)
  /// fontWeight: 400 (regular)
  /// lineHeight: 1.4
  static const TextStyle label = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: fontWeightRegular,
    height: 1.4,
  );
  
  /// 按钮文本样式
  /// 
  /// fontSize: 16px (base)
  /// fontWeight: 600 (semiBold)
  /// lineHeight: 1.0
  static const TextStyle button = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemiBold,
    height: 1.0,
  );
  
  /// 数字样式（等宽字体）
  /// 
  /// fontSize: 16px (base)
  /// fontWeight: 500 (medium)
  /// fontFamily: SF Mono
  static const TextStyle numeric = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    fontFamily: fontFamilyMono,
    height: lineHeightNormal,
  );
}
