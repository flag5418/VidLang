import 'package:flutter/material.dart';

/// 配色系统 — 日落渐变方案
///
/// 设计原则：
/// - 纯黑背景与浮层之间有清晰的层级分离
/// - 主色调为珊瑚红(#FF6B6B)，辅色为暖橙(#FF8E53)，形成日落渐变
/// - 文字/前景色保持高对比度
/// - 表面色有足够区分度，不糊在一起
/// - 非活跃元素统一用较低透明度，避免灰色喧宾夺主
class AppColors {
  AppColors._();

  // ─── 背景层级 ─────────────────────────────────
  // 极黑基底 → 逐层抬升，层级分明
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceHighest = Color(0xFF2C2C2C);

  // ─── 前景/文字 ─────────────────────────────────
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFF999999);
  static const Color onSurfaceDisabled = Color(0xFF555555);

  // ─── 强调色（日落渐变：珊瑚红 → 暖橙） ────
  /// 主色：珊瑚红
  static const Color primary = Color(0xFF4284FC);

  /// 辅色/渐变终点：暖橙
  static const Color secondary = Color(0xFFFF8E53);
  static const Color primaryContainer = Color(0xFF552020);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ─── 日落渐变（用于按钮、进度条等强调元素）────
  static const LinearGradient sunsetGradient = LinearGradient(colors: [primary, secondary], begin: Alignment.centerLeft, end: Alignment.centerRight);

  /// 用日落渐变装饰的 BoxDecoration（圆角按钮/胶囊）
  static BoxDecoration sunsetBoxDecoration({double radius = 20}) =>
      BoxDecoration(gradient: sunsetGradient, borderRadius: BorderRadius.circular(radius));

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
  static const Color playerButtonActive = Color(0xFFFF6B6B);
  static const Color playerButtonInactive = Color(0x33FFFFFF);
  static const Color playerButtonDisabledText = Color(0xFF555555);
  static const Color playerProgressBuffered = Color(0x33FFFFFF);
  static const Color playerProgressInactive = Color(0x1AFFFFFF);
  static const Color playerProgressActive = Color(0xFFFFFFFF);
  static const Color playerPopupBackground = Color(0xF0101010);
  static const Color playerTimerChipColor = Color(0xFFFF6B6B);
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

  // ─── 卡片/封面专用 ──────────────────────────────
  /// 卡片缩略图区域的背景色（深灰，近似视频加载前的底色）
  static const Color cardThumbnailBg = Color(0xFF1A1A1A);

  /// 卡片上标签/徽章的背景
  static const Color badgeBg = Color(0xDD000000);

  /// 第三层表面色（比 surfaceHighest 再高一级）
  static const Color surfaceTertiary = Color(0xFF363636);
}
