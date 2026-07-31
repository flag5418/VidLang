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

  // ─── 扩展语义色（覆盖 colorScheme 全集）─────
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onPrimary;
  final Color primaryContainer;
  final Color outline;
  final Color outlineVariant;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color errorColor;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color inversePrimary;
  final Color onError;
  final Color onErrorContainer;
  final Color onPrimaryContainer;
  final Color errorContainer;

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
    // ─── 扩展语义色 ──────────────────────────────
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onPrimary,
    required this.primaryContainer,
    required this.outline,
    required this.outlineVariant,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.errorColor,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.inversePrimary,
    required this.onError,
    required this.onErrorContainer,
    required this.onPrimaryContainer,
    required this.errorContainer,
  });

  static const light = AppColorsData(
    background: Color(0xFFFBFDFF),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textWeak: Color(0xFF94A3B8),
    border: Color(0xFFF1F5F9),
    primary: Color(0xFF3B6EFF),
    primaryDark: Color(0xFF2563EB),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    videoType: Color(0xFF3B6EFF),
    articleType: Color(0xFFF97316),
    audioType: Color(0xFF8B5CF6),
    // ─── 扩展语义色（亮色）──────────────────────────
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF475569),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEFF6FF),
    outline: Color(0xFFF1F5F9),
    outlineVariant: Color(0xFFE2E8F0),
    surfaceContainerLow: Color(0xFFFBFDFF),
    surfaceContainer: Color(0xFFF8FAFC),
    surfaceContainerHigh: Color(0xFFF1F5F9),
    surfaceContainerHighest: Color(0xFFEFF6FF),
    errorColor: Color(0xFFEF4444),
    tertiary: Color(0xFF3B6EFF),
    tertiaryContainer: Color(0xFFDCE8FF),
    onTertiaryContainer: Color(0xFF001946),
    inversePrimary: Color(0xFF2563EB),
    onError: Color(0xFFFFFFFF),
    onErrorContainer: Color(0xFF9B0021),
    onPrimaryContainer: Color(0xFF001B3E),
    errorContainer: Color(0xFFFFDAD6),
  );

  static const dark = AppColorsData(
    background: Color(0xFF09090B),
    surface: Color(0xFF18181B),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textWeak: Color(0xFF52525B),
    border: Color(0xFF27272A),
    primary: Color(0xFF60A5FA),
    primaryDark: Color(0xFF3B82F6),
    error: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    videoType: Color(0xFF60A5FA),
    articleType: Color(0xFFFB923C),
    audioType: Color(0xFFA78BFA),
    // ─── 扩展语义色（暗色）──────────────────────────
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFA1A1AA),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF0D2D68),
    outline: Color(0xFF3A3A3A),
    outlineVariant: Color(0xFF484848),
    surfaceContainerLow: Color(0xFF141414),
    surfaceContainer: Color(0xFF1E1E1E),
    surfaceContainerHigh: Color(0xFF27272A),
    surfaceContainerHighest: Color(0xFF27272A),
    errorColor: Color(0xFFF87171),
    tertiary: Color(0xFFAAC7FF),
    tertiaryContainer: Color(0xFF00306A),
    onTertiaryContainer: Color(0xFFD2E2FF),
    inversePrimary: Color(0xFF60A5FA),
    onError: Color(0xFFFFFFFF),
    onErrorContainer: Color(0xFF69000F),
    onPrimaryContainer: Color(0xFFD2E2FF),
    errorContainer: Color(0xFF69000F),
  );
}

extension AppColorsExtension on BuildContext {
  /// 语义颜色（自动适配亮/暗主题）
  AppColorsData get colors {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark ? AppColorsData.dark : AppColorsData.light;
  }

  /// 当前主题亮度（统一入口，禁止再使用 Theme.of(context).brightness）
  Brightness get brightness => Theme.of(this).brightness;

  /// 是否暗色模式
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ═══════════════════════════════════════════════════════════════
// 静态颜色 API（向后兼容）
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ─── 品牌色 ────────────────────────────────────
  static const Color primaryBrand = Color(0xFF3B6EFF);
  static const Color primaryBrandLight = Color(0xFFDBEAFE);
  static const Color primaryBrandDark = Color(0xFF2563EB);

  // ─── 语义色 ────────────────────────────────────
  static const Color info = Color(0xFF3B82F6);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color premium = Color(0xFFF59E0B); // VIP/高级会员金色

  // ─── 中性色（亮色）──────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  static const Color backgroundLight = Color(0xFFFBFDFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSecondaryLight = Color(0xFFF8FAFC);

  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderLightLight = Color(0xFFF8FAFC);

  // ─── 中性色（暗色）──────────────────────────────
  static const Color backgroundDark = Color(0xFF09090B);
  static const Color surfaceDark = Color(0xFF18181B);
  static const Color surfaceSecondaryDark = Color(0xFF27272A);

  static const Color borderDark = Color(0xFF27272A);

  // ─── 向后兼容层：背景层级 ──────────────────────
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0F0F11);
  static const Color surfaceElevated = Color(0xFF1A1A1D);
  static const Color surfaceHighest = Color(0xFF27272A);

  static const Color lightBackground = backgroundLight;
  static const Color lightSurface = surfaceLight;
  static const Color lightSurfaceElevated = surfaceSecondaryLight;
  static const Color lightSurfaceHighest = Color(0xFFEFF6FF);

  static Color getBgLayer({required Brightness brightness}) => brightness == Brightness.dark ? surface : lightSurface;
  static Color getScaffoldBg({required Brightness brightness}) => brightness == Brightness.dark ? background : lightBackground;
  static Color getSurface({required Brightness brightness}) => brightness == Brightness.dark ? surface : lightSurface;
  static Color getSurfaceElevated({required Brightness brightness}) => brightness == Brightness.dark ? surfaceElevated : lightSurfaceElevated;
  static Color getSurfaceHighest({required Brightness brightness}) => brightness == Brightness.dark ? surfaceHighest : lightSurfaceHighest;

  // ─── 向后兼容层：前景/文字色 ──────────────────
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFFA1A1AA);
  static const Color onSurfaceDisabled = Color(0xFF71717A);

  static const Color lightOnSurface = textPrimary;
  static const Color lightOnSurfaceVariant = textSecondary;
  static const Color lightOnSurfaceDisabled = textDisabled;

  static Color getOnSurface({required Brightness brightness}) => brightness == Brightness.dark ? onSurface : lightOnSurface;
  static Color getOnSurfaceVariant({required Brightness brightness}) => brightness == Brightness.dark ? onSurfaceVariant : lightOnSurfaceVariant;

  static Color getOutline({required Brightness brightness}) => brightness == Brightness.dark ? outline : borderLight;

  // ─── 强调色（向后兼容蓝橙）────────────────────
  static const Color primary = Color(0xFF3B6EFF);
  static const Color secondary = Color(0xFF2563EB);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B6EFF), Color(0xFF2563EB)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientReverse = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B6EFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const RadialGradient primaryRadialGradient = RadialGradient(colors: [Color(0x4C3B6EFF), Color(0x003B6EFF)], stops: [0.0, 1.0]);

  static BoxDecoration gradientBoxDecoration({double radius = 20}) =>
      BoxDecoration(gradient: primaryGradient, borderRadius: BorderRadius.circular(radius));

  @Deprecated('Use primaryGradient instead')
  static const LinearGradient sunsetGradient = primaryGradient;

  // ─── 功能色 ────────────────────────────────────
  static const Color outline = Color(0xFF3A3A3A);
  static const Color outlineVariant = Color(0xFF484848);
  static const Color divider = Color(0x1AFFFFFF);

  // ─── 播放器专用 ─────────────────────────────────
  static const Color playerOverlayGradient = Color(0xCC000000);
  static const Color playerButtonDim = Color(0x1AFFFFFF);
  static const Color playerButtonActive = Color(0xFF3B6EFF);
  static const Color playerButtonInactive = Color(0x33FFFFFF);
  static const Color playerButtonDisabledText = Color(0xFF71717A);
  static const Color playerProgressBuffered = Color(0x33FFFFFF);
  static const Color playerProgressInactive = Color(0x1AFFFFFF);
  static const Color playerProgressActive = Color(0xFFFFFFFF);
  static const Color playerPopupBackground = Color(0xF0101010);
  static const Color playerTimerChipColor = Color(0xFF3B6EFF);
  static const Color playerSubtitleBg = Color(0x99000000);
  static const Color playerSubtitleTranslate = Color(0xFFFFE082);

  // ─── 图标/导航 ──────────────────────────────────
  static const Color iconDefault = Color(0xFF94A3B8);
  static const Color iconActive = Color(0xFF3B6EFF);

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
    surfaceContainerLow: Color(0xFF141414),
    surfaceContainer: Color(0xFF1E1E1E),
    surfaceContainerHigh: Color(0xFF27272A),
    outline: outline,
    outlineVariant: outlineVariant,
    error: error,
    onError: Color(0xFFFFFFFF),
    shadow: Color(0x00000000),
  );

  static const Color lightIconDefault = Color(0xFF94A3B8);
  static const Color lightIconActive = Color(0xFF3B6EFF);

  static ColorScheme get lightColorScheme => const ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    secondary: secondary,
    onSecondary: Color(0xFFFFFFFF),
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceContainerHighest: lightSurfaceHighest,
    onSurfaceVariant: lightOnSurfaceVariant,
    surfaceContainerLow: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFF1F5F9),
    outline: Color(0xFFF1F5F9),
    outlineVariant: Color(0xFFE2E8F0),
    error: error,
    onError: Color(0xFFFFFFFF),
    shadow: Color(0x00000000),
  );

  // ─── 卡片/封面专用 ──────────────────────────────
  static const Color cardThumbnailBg = Color(0xFF1A1A1A);
  static const Color badgeBg = Color(0xDD000000);
  static const Color surfaceTertiary = Color(0xFF363636);

  // ─── 三类资源类型色 ──────────────────────────────
  static const Color videoColor = Color(0xFF3B6EFF);
  static const Color articleColor = Color(0xFFF97316);
  static const Color audioColor = Color(0xFF8B5CF6);

  static Color videoCardBg(Brightness brightness) => videoColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);
  static Color articleCardBg(Brightness brightness) => articleColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);
  static Color audioCardBg(Brightness brightness) => audioColor.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);

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
