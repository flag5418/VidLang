import 'package:flutter/material.dart';

/// 配色系统 — 基于 Pencil UI Design Skill 的工业级设计规范
///
/// 设计原则（v2.0 更新）：
/// - 语义化颜色体系：品牌色、语义色、中性色、表面色分离管理
/// - 完整的亮色/暗色主题支持
/// - 4px 基础网格系统
/// - Material Symbols Rounded 图标库统一
/// - 高对比度和无障碍访问支持
///
/// 兼容性说明：
/// - 保留原有的蓝橙渐变方案作为播放器专用配色
/// - 新增 Pencil Skill 规范的中性色和表面色系统
/// - 所有颜色常量保持向后兼容

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════
  // Pencil Skill 设计系统 — 中性色（灰阶）
  // ═══════════════════════════════════════════════════════════════

  /// 文本主色 - 用于标题、重要文字
  static const Color textPrimary = Color(0xFF18181B);
  
  /// 文本次要色 - 用于辅助文字、描述
  static const Color textSecondary = Color(0xFF71717A);
  
  /// 文本三级色 - 用于占位符、禁用状态提示
  static const Color textTertiary = Color(0xFFA1A1AA);
  
  /// 文本禁用色 - 用于禁用状态的文字
  static const Color textDisabled = Color(0xFFD4D4D8);

  /// 页面背景色（亮色模式）
  static const Color backgroundLight = Color(0xFFFAFAFA);
  
  /// 卡片/容器背景色（亮色模式）
  static const Color surfaceLight = Color(0xFFFFFFFF);
  
  /// 次要表面色（亮色模式）
  static const Color surfaceSecondaryLight = Color(0xFFF4F4F5);

  /// 边框色（亮色模式）
  static const Color borderLight = Color(0xFFE4E4E7);
  
  /// 浅边框色（亮色模式）
  static const Color borderLightLight = Color(0xFFF4F4F5);

  // 暗色主题的中性色
  /// 页面背景色（暗色模式）- #18181B
  static const Color backgroundDark = Color(0xFF18181B);
  
  /// 卡片/容器背景色（暗色模式）
  static const Color surfaceDark = Color(0xFF18181B);
  
  /// 次要表面色（暗色模式）
  static const Color surfaceSecondaryDark = Color(0xFF27272A);

  /// 边框色（暗色模式）
  static const Color borderDark = Color(0xFF27272A);

  // ═══════════════════════════════════════════════════════════════
  // Pencil Skill 设计系统 — 品牌色（保留多邻国风格的翠绿色）
  // ═══════════════════════════════════════════════════════════════

  /// 主品牌色 - 翠绿色（用于主要操作、进度条、强调元素）
  static const Color primaryBrand = Color(0xFF4ADE80);
  
  /// 主品牌色浅色版
  static const Color primaryBrandLight = Color(0xFFDCFCE7);
  
  /// 主品牌色深色版
  static const Color primaryBrandDark = Color(0xFF22C55E);
  
  /// 信息提示色（Pencil Skill 新增）
  static const Color info = Color(0xFF3B82F6);

  // ═══════════════════════════════════════════════════════════════
  // 向后兼容层 — 背景层级（原有 API 保持不变）
  // ═══════════════════════════════════════════════════════════════

  // 暗色主题背景层级
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceHighest = Color(0xFF2C2C2C);

  // 亮色主题背景层级（使用 Pencil Skill 规范值）
  static const Color lightBackground = backgroundLight; // #FAFAFA
  static const Color lightSurface = surfaceLight;     // #FFFFFF
  static const Color lightSurfaceElevated = surfaceSecondaryLight; // #F4F4F5
  static const Color lightSurfaceHighest = Color(0xFFF5F6FC);

  /// 根据主题获取背景层级色（Pencil Skill 优化版）
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

  // ═══════════════════════════════════════════════════════════════
  // 向后兼容层 — 前景/文字色
  // ═══════════════════════════════════════════════════════════════

  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFF999999);
  static const Color onSurfaceDisabled = Color(0xFF555555);
  static const Color lightOnSurface = textPrimary;       // #18181B (Pencil Skill)
  static const Color lightOnSurfaceVariant = textSecondary; // #71717A (Pencil Skill)
  static const Color lightOnSurfaceDisabled = textDisabled;  // #D4D4D8 (Pencil Skill)

  /// 根据主题获取前景文字色（Pencil Skill 优化版）
  static Color getOnSurface({required Brightness brightness}) =>
      brightness == Brightness.dark ? onSurface : lightOnSurface;
  static Color getOnSurfaceVariant({required Brightness brightness}) =>
      brightness == Brightness.dark ? onSurfaceVariant : lightOnSurfaceVariant;

  /// 根据主题获取边框/分隔色（Pencil Skill 优化版）
  static Color getOutline({required Brightness brightness}) =>
      brightness == Brightness.dark ? outline : borderLight;

  // ═══════════════════════════════════════════════════════════════
  // 强调色系统（电光蓝 → 暖橙渐变）— 播放器和功能模块专用
  // ═══════════════════════════════════════════════════════════════

  /// 主色：电光蓝（用于播放器、导航等）
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
