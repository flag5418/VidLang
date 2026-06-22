import 'package:flutter/material.dart';

/// 配色系统 — 蓝橙渐变方案
///
/// 设计原则：
/// - 纯黑背景与浮层之间有清晰的层级分离
/// - 主色调为电光蓝(#4284FC)，辅色为暖橙(#FF8E53)，形成视觉渐变
/// - 文字/前景色保持高对比度
/// - 表面色有足够区分度，不糊在一起
/// - 非活跃元素统一用较低透明度，避免灰色喧宾夺主
class AppColors {
  AppColors._();

  // ─── 背景层级 ─────────────────────────────────
  // 暗色主题
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceHighest = Color(0xFF2C2C2C);

  // 亮色主题
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF0F0F0);
  static const Color lightSurfaceHighest = Color(0xFFE8E8E8);

  /// 根据主题获取背景层级色
  static Color getBgLayer({required Brightness brightness}) =>
      brightness == Brightness.dark ? surface : lightSurface;
  static Color getScaffoldBg({required Brightness brightness}) =>
      brightness == Brightness.dark ? background : lightBackground;
  static Color getSurface({required Brightness brightness}) =>
      brightness == Brightness.dark ? surface : lightSurface;
  static Color getSurfaceElevated({required Brightness brightness}) =>
      brightness == Brightness.dark ? surfaceElevated : lightSurfaceElevated;
  static Color getSurfaceHighest({required Brightness brightness}) =>
      brightness == Brightness.dark ? surfaceHighest : lightSurfaceHighest;

  // ─── 前景/文字 ─────────────────────────────────
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFF999999);
  static const Color onSurfaceDisabled = Color(0xFF555555);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF666666);
  static const Color lightOnSurfaceDisabled = Color(0xFFAAAAAA);

  /// 根据主题获取前景文字色
  static Color getOnSurface({required Brightness brightness}) =>
      brightness == Brightness.dark ? onSurface : lightOnSurface;
  static Color getOnSurfaceVariant({required Brightness brightness}) =>
      brightness == Brightness.dark ? onSurfaceVariant : lightOnSurfaceVariant;

  // ─── 强调色（电光蓝 → 暖橙渐变） ────
  /// 主色：电光蓝
  static const Color primary = Color(0xFF4284FC);

  /// 辅色/渐变终点：暖橙
  static const Color secondary = Color(0xFFFF8E53);
  static const Color primaryContainer = Color(0xFF203555);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ─── 蓝橙渐变（用于按钮、进度条等强调元素）────
  static const LinearGradient primaryGradient = LinearGradient(colors: [primary, secondary], begin: Alignment.centerLeft, end: Alignment.centerRight);

  /// 反向蓝橙渐变
  static const LinearGradient primaryGradientReverse = LinearGradient(colors: [secondary, primary], begin: Alignment.centerLeft, end: Alignment.centerRight);

  /// 蓝色径向渐变（用于光晕效果）
  static const RadialGradient primaryRadialGradient = RadialGradient(colors: [Color(0x4C4284FC), Color(0x004284FC)], stops: [0.0, 1.0]);

  /// 用蓝橙渐变装饰的 BoxDecoration（圆角按钮/胶囊）
  static BoxDecoration gradientBoxDecoration({double radius = 20}) =>
      BoxDecoration(gradient: primaryGradient, borderRadius: BorderRadius.circular(radius));

  /// 日落渐变（向后兼容，等同于 primaryGradient）
  @Deprecated('Use primaryGradient instead')
  static const LinearGradient sunsetGradient = primaryGradient;

  // ─── 语义色 ────────────────────────────────────
  static const Color error = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFCC00);

  // ─── 功能性 ────────────────────────────────────
  static const Color outline = Color(0xFF3A3A3A);
  static const Color outlineVariant = Color(0xFF484848);
  static const Color divider = Color(0x1AFFFFFF);

  // ─── 播放器专用 ─────────────────────────────────
  static const Color playerOverlayGradient = Color(0xCC000000);
  static const Color playerButtonDim = Color(0x1AFFFFFF);
  static const Color playerButtonActive = Color(0xFF4284FC);
  static const Color playerButtonInactive = Color(0x33FFFFFF);
  static const Color playerButtonDisabledText = Color(0xFF555555);
  static const Color playerProgressBuffered = Color(0x33FFFFFF);
  static const Color playerProgressInactive = Color(0x1AFFFFFF);
  static const Color playerProgressActive = Color(0xFFFFFFFF);
  static const Color playerPopupBackground = Color(0xF0101010);
  static const Color playerTimerChipColor = Color(0xFF4284FC);
  static const Color playerSubtitleBg = Color(0x99000000);
  static const Color playerSubtitleTranslate = Color(0xFFFFE082);

  // ─── 图标/导航 ──────────────────────────────────
  static const Color iconDefault = Color(0xFF8A8A8A);
  static const Color iconActive = Color(0xFF4284FC);

  // ─── ColorScheme（供 TDesign / Material3 兼容） ─────
  static ColorScheme get darkColorScheme => const ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    secondary: secondary,
    onSecondary: Color(0xFFFFFFFF),
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceHighest,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainerLow: Color(0xFF1A1A1A),
    surfaceContainer: Color(0xFF222222),
    surfaceContainerHigh: Color(0xFF2C2C2C),
    outline: outline,
    outlineVariant: outlineVariant,
    error: error,
    onError: Color(0xFFFFFFFF),
    shadow: Color(0x00000000),
  );

  // ─── 亮色主题图标/导航 ────────────────────────────
  static const Color lightIconDefault = Color(0xFF888888);
  static const Color lightIconActive = Color(0xFF4284FC);

  static ColorScheme get lightColorScheme => const ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCE6FF),
    secondary: secondary,
    onSecondary: Color(0xFFFFFFFF),
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceContainerHighest: lightSurfaceHighest,
    onSurfaceVariant: lightOnSurfaceVariant,
    surfaceContainerLow: Color(0xFFFAFAFA),
    surfaceContainer: Color(0xFFF5F5F5),
    surfaceContainerHigh: Color(0xFFEEEEEE),
    outline: Color(0xFFDDDDDD),
    outlineVariant: Color(0xFFCCCCCC),
    error: error,
    onError: Color(0xFFFFFFFF),
    shadow: Color(0x00000000),
  );

  // ─── 卡片/封面专用 ──────────────────────────────
  /// 卡片缩略图区域的背景色（深灰，近似视频加载前的底色）
  static const Color cardThumbnailBg = Color(0xFF1A1A1A);

  /// 卡片上标签/徽章的背景
  static const Color badgeBg = Color(0xDD000000);

  /// 第三层表面色（比 surfaceHighest 再高一级）
  static const Color surfaceTertiary = Color(0xFF363636);

  // ─── 三类资源类型色（独立于主题，深/浅皆醒目） ────
  /// 视频 - 蓝色（沿用 primary）
  static const Color videoColor = Color(0xFF4284FC);
  /// 视频卡片背景（dark 20%, light 12%）
  static Color videoCardBg(Brightness brightness) =>
      videoColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);

  /// 文章 - 暖橙
  static const Color articleColor = Color(0xFFFF8E53);
  static Color articleCardBg(Brightness brightness) =>
      articleColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);

  /// 音频 - 紫色
  static const Color audioColor = Color(0xFFA855F7);
  static Color audioCardBg(Brightness brightness) =>
      audioColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);

  // ─── 文章卡片调色板（10+ 种颜色，按标题哈希分配） ──
  static const List<Color> articlePalette = [
    Color(0xFF2563EB), // 蓝
    Color(0xFF059669), // 翡翠绿
    Color(0xFFD97706), // 琥珀
    Color(0xFFDC2626), // 红
    Color(0xFF7C3AED), // 紫
    Color(0xFFDB2777), // 粉红
    Color(0xFF0891B2), // 青
    Color(0xFF4F46E5), // 靛蓝
    Color(0xFFEA580C), // 橙
    Color(0xFF0D9488), // 茶绿
    Color(0xFF9333EA), // 紫罗兰
    Color(0xFF15803D), // 绿
  ];

  /// 根据文章标题分配颜色
  static Color articleColorFor(String title) {
    final hash = title.hashCode;
    return articlePalette[hash.abs() % articlePalette.length];
  }

  /// 获取类型色
  static Color colorForType(String type, {required Brightness brightness}) {
    switch (type) {
      case 'article':
        return articleColor;
      case 'music':
        return audioColor;
      default:
        return videoColor;
    }
  }

  /// 获取类型卡片背景色
  static Color cardBgForType(String type, {required Brightness brightness}) {
    switch (type) {
      case 'article':
        return articleCardBg(brightness);
      case 'music':
        return audioCardBg(brightness);
      default:
        return videoCardBg(brightness);
    }
  }
}
