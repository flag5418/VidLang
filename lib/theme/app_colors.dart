import 'package:flutter/material.dart';

/// 配色系统 — VidLang 设计升级 v3.0
///
/// 设计原则：
/// - 统一的品牌绿主色调（#4ADE80 / #22C55E）
/// - 完整的亮色/暗色双模式
/// - BuildContext 扩展 `context.colors` 自动切换
/// - 保留旧 API 向后兼容
///
/// 兼容性说明：
/// - 原有 AppColors 静态类全部保留
/// - 新增 AppColorsData + AppColorsExtension 提供 context.colors

// ═══════════════════════════════════════════════════════════════
// 运行时颜色数据容器（context.colors 返回此类型）
// ═══════════════════════════════════════════════════════════════

class AppColorsData {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textWeak;
  final Color border;
  final Color primary;
  final Color primaryDark;
  final Color error;
  final Color warning;
  final Color videoType;
  final Color articleType;
  final Color audioType;

  const AppColorsData({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textWeak,
    required this.border,
    required this.primary,
    required this.primaryDark,
    required this.error,
    required this.warning,
    required this.videoType,
    required this.articleType,
    required this.audioType,
  });

  static const light = AppColorsData(
    background:   Color(0xFFFAFAF9),
    surface:      Color(0xFFFFFFFF),
    textPrimary:  Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8E8E93),
    textWeak:     Color(0xFFC7C7CC),
    border:       Color(0xFFE5E5E5),
    primary:      Color(0xFF4284FC),
    primaryDark:  Color(0xFF3367D6),
    error:        Color(0xFFFF3B30),
    warning:      Color(0xFFFF9500),
    videoType:    Color(0xFF4284FC),
    articleType:  Color(0xFFFF8E53),
    audioType:    Color(0xFFA855F7),
  );

  static const dark = AppColorsData(
    background:   Color(0xFF0D0D0D),
    surface:      Color(0xFF1C1C1E),
    textPrimary:  Color(0xFFF5F5F7),
    textSecondary: Color(0xFF98989D),
    textWeak:     Color(0xFF48484A),
    border:       Color(0xFF38383A),
    primary:      Color(0xFF4284FC),
    primaryDark:  Color(0xFF3367D6),
    error:        Color(0xFFFF453A),
    warning:      Color(0xFFFF9F0A),
    videoType:    Color(0xFF5B9FFF),
    articleType:  Color(0xFFFF9F6B),
    audioType:    Color(0xFFC084FC),
  );
}

extension AppColorsExtension on BuildContext {
  AppColorsData get colors {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark ? AppColorsData.dark : AppColorsData.light;
  }
}

// ═══════════════════════════════════════════════════════════════
// 静态颜色 API（向后兼容）
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ─── 品牌色 ────────────────────────────────────
  static const Color primaryBrand       = Color(0xFF4284FC);
  static const Color primaryBrandLight  = Color(0xFFDCFCE7);
  static const Color primaryBrandDark   = Color(0xFF3367D6);

  // ─── 语义色 ────────────────────────────────────
  static const Color info    = Color(0xFF3B82F6);
  static const Color error   = Color(0xFFFF3B30);
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9500);

  // ─── 中性色（亮色）──────────────────────────────
  static const Color textPrimary    = Color(0xFF1C1C1E);
  static const Color textSecondary  = Color(0xFF8E8E93);
  static const Color textTertiary   = Color(0xFFC7C7CC);
  static const Color textDisabled   = Color(0xFFD4D4D8);

  static const Color backgroundLight         = Color(0xFFFAFAF9);
  static const Color surfaceLight            = Color(0xFFFFFFFF);
  static const Color surfaceSecondaryLight   = Color(0xFFF4F4F5);

  static const Color borderLight       = Color(0xFFE5E5E5);
  static const Color borderLightLight  = Color(0xFFF4F4F5);

  // ─── 中性色（暗色）──────────────────────────────
  static const Color backgroundDark          = Color(0xFF0D0D0D);
  static const Color surfaceDark             = Color(0xFF1C1C1E);
  static const Color surfaceSecondaryDark    = Color(0xFF2C2C2E);

  static const Color borderDark = Color(0xFF38383A);

  // ─── 向后兼容层：背景层级 ──────────────────────
  static const Color background      = Color(0xFF000000);
  static const Color surface         = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceHighest  = Color(0xFF2C2C2C);

  static const Color lightBackground      = backgroundLight;
  static const Color lightSurface         = surfaceLight;
  static const Color lightSurfaceElevated = surfaceSecondaryLight;
  static const Color lightSurfaceHighest  = Color(0xFFF5F6FC);

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

  // ─── 向后兼容层：前景/文字色 ──────────────────
  static const Color onSurface          = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant   = Color(0xFF999999);
  static const Color onSurfaceDisabled  = Color(0xFF555555);

  static const Color lightOnSurface         = textPrimary;
  static const Color lightOnSurfaceVariant  = textSecondary;
  static const Color lightOnSurfaceDisabled = textDisabled;

  static Color getOnSurface({required Brightness brightness}) =>
      brightness == Brightness.dark ? onSurface : lightOnSurface;
  static Color getOnSurfaceVariant({required Brightness brightness}) =>
      brightness == Brightness.dark ? onSurfaceVariant : lightOnSurfaceVariant;

  static Color getOutline({required Brightness brightness}) =>
      brightness == Brightness.dark ? outline : borderLight;

  // ─── 强调色（向后兼容蓝橙）────────────────────
  static const Color primary        = Color(0xFF4284FC);
  static const Color secondary      = Color(0xFF3367D6);
  static const Color primaryContainer = Color(0xFF166534);
  static const Color onPrimary      = Color(0xFFFFFFFF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4284FC), Color(0xFF3367D6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientReverse = LinearGradient(
    colors: [Color(0xFF3367D6), Color(0xFF4284FC)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const RadialGradient primaryRadialGradient = RadialGradient(
    colors: [Color(0x4C4284FC), Color(0x004284FC)],
    stops: [0.0, 1.0],
  );

  static BoxDecoration gradientBoxDecoration({double radius = 20}) =>
      BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(radius),
      );

  @Deprecated('Use primaryGradient instead')
  static const LinearGradient sunsetGradient = primaryGradient;

  // ─── 功能色 ────────────────────────────────────
  static const Color outline        = Color(0xFF3A3A3A);
  static const Color outlineVariant = Color(0xFF484848);
  static const Color divider        = Color(0x1AFFFFFF);

  // ─── 播放器专用 ─────────────────────────────────
  static const Color playerOverlayGradient      = Color(0xCC000000);
  static const Color playerButtonDim            = Color(0x1AFFFFFF);
  static const Color playerButtonActive         = Color(0xFF4284FC);
  static const Color playerButtonInactive       = Color(0x33FFFFFF);
  static const Color playerButtonDisabledText   = Color(0xFF555555);
  static const Color playerProgressBuffered     = Color(0x33FFFFFF);
  static const Color playerProgressInactive     = Color(0x1AFFFFFF);
  static const Color playerProgressActive       = Color(0xFFFFFFFF);
  static const Color playerPopupBackground      = Color(0xF0101010);
  static const Color playerTimerChipColor       = Color(0xFF4284FC);
  static const Color playerSubtitleBg           = Color(0x99000000);
  static const Color playerSubtitleTranslate    = Color(0xFFFFE082);

  // ─── 图标/导航 ──────────────────────────────────
  static const Color iconDefault = Color(0xFF8A8A8A);
  static const Color iconActive  = Color(0xFF4284FC);

  // ─── ColorScheme（TDesign / Material3 兼容）────
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

  static const Color lightIconDefault = Color(0xFF888888);
  static const Color lightIconActive  = Color(0xFF4284FC);

  static ColorScheme get lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFDCFCE7),
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
  static const Color cardThumbnailBg = Color(0xFF1A1A1A);
  static const Color badgeBg         = Color(0xDD000000);
  static const Color surfaceTertiary = Color(0xFF363636);

  // ─── 三类资源类型色 ──────────────────────────────
  static const Color videoColor   = Color(0xFF4284FC);
  static const Color articleColor = Color(0xFFFF8E53);
  static const Color audioColor   = Color(0xFFA855F7);

  static Color videoCardBg(Brightness brightness) =>
      videoColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);
  static Color articleCardBg(Brightness brightness) =>
      articleColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);
  static Color audioCardBg(Brightness brightness) =>
      audioColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);

  // ─── 文章卡片调色板 ──────────────────────────────
  static const List<Color> articlePalette = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF4F46E5),
    Color(0xFFEA580C),
    Color(0xFF0D9488),
    Color(0xFF9333EA),
    Color(0xFF15803D),
  ];

  static Color articleColorFor(String title) {
    final hash = title.hashCode;
    return articlePalette[hash.abs() % articlePalette.length];
  }

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
