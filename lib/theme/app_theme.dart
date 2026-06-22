import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: AppColors.lightColorScheme,
    fontFamily: AppTypography.fontFamilySans,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.lightBackground,
    canvasColor: AppColors.lightSurface,
    dividerColor: AppColors.lightDivider,

    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightOnSurface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(color: AppColors.lightOnSurface, fontSize: 18, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: AppColors.lightOnSurface),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: AppColors.lightSurface,
      surfaceTintColor: AppColors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      margin: EdgeInsets.all(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space4),
        minimumSize: const Size(0, AppSpacing.space10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space4),
        minimumSize: const Size(0, AppSpacing.space10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        side: BorderSide(color: AppColors.lightOutline),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.lightOnSurface)),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceElevated,
      contentPadding: const EdgeInsets.all(AppSpacing.inputPadding),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(color: AppColors.lightOnSurfaceDisabled, fontSize: AppTypography.fontSizeBase),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: AppTypography.fontSizeSmall, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: AppTypography.fontSizeSmall),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
      titleTextStyle: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: AppColors.lightOnSurface),
      contentTextStyle: TextStyle(fontSize: AppTypography.fontSizeBase, color: AppColors.lightOnSurface),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.lightOutlineVariant,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightSurfaceHighest,
      contentTextStyle: TextStyle(color: AppColors.lightOnSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      behavior: SnackBarBehavior.floating,
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.lightSurfaceHighest,
      linearMinHeight: 4,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.lightSurfaceHighest,
      thumbColor: AppColors.primary,
      trackHeight: 4,
    ),

    textTheme: TextTheme(
      displayLarge: TextStyle(color: AppColors.lightOnSurface),
      displayMedium: TextStyle(color: AppColors.lightOnSurface),
      displaySmall: TextStyle(color: AppColors.lightOnSurface),
      headlineLarge: TextStyle(color: AppColors.lightOnSurface),
      headlineMedium: TextStyle(color: AppColors.lightOnSurface),
      headlineSmall: TextStyle(color: AppColors.lightOnSurface),
      titleLarge: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: AppColors.lightOnSurface, letterSpacing: 0.2),
      titleMedium: TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w500, color: AppColors.lightOnSurface),
      titleSmall: TextStyle(fontSize: AppTypography.fontSizeSmall, fontWeight: FontWeight.w500, color: AppColors.lightOnSurface),
      bodyLarge: TextStyle(color: AppColors.lightOnSurface),
      bodyMedium: TextStyle(color: AppColors.lightOnSurface),
      bodySmall: TextStyle(color: AppColors.lightOnSurfaceVariant),
      labelLarge: TextStyle(color: AppColors.lightOnSurface),
      labelMedium: TextStyle(color: AppColors.lightOnSurface),
      labelSmall: TextStyle(color: AppColors.lightOnSurfaceVariant),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: AppColors.darkColorScheme,
    fontFamily: AppTypography.fontFamilySans,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.surface,
    dividerColor: AppColors.divider,

    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: const TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
      iconTheme: const IconThemeData(color: AppColors.onSurface),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: AppColors.surfaceElevated,
      surfaceTintColor: AppColors.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      margin: EdgeInsets.all(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.white.withValues(alpha: 0.06),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space4),
        minimumSize: const Size(0, AppSpacing.space10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space4),
        minimumSize: const Size(0, AppSpacing.space10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        side: const BorderSide(color: AppColors.outline),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.onSurface)),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.all(AppSpacing.inputPadding),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.onSurfaceDisabled, fontSize: AppTypography.fontSizeBase),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: AppTypography.fontSizeSmall, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: AppTypography.fontSizeSmall),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
      titleTextStyle: const TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: AppColors.onSurface),
      contentTextStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, color: AppColors.onSurface),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.outlineVariant,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceElevated,
      contentTextStyle: const TextStyle(color: AppColors.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      behavior: SnackBarBehavior.floating,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.surfaceHighest,
      linearMinHeight: 4,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.surfaceHighest,
      thumbColor: AppColors.primary,
      trackHeight: 4,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.onSurface),
      displayMedium: TextStyle(color: AppColors.onSurface),
      displaySmall: TextStyle(color: AppColors.onSurface),
      headlineLarge: TextStyle(color: AppColors.onSurface),
      headlineMedium: TextStyle(color: AppColors.onSurface),
      headlineSmall: TextStyle(color: AppColors.onSurface),
      titleLarge: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: AppColors.onSurface, letterSpacing: 0.2),
      titleMedium: TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w500, color: AppColors.onSurface),
      titleSmall: TextStyle(fontSize: AppTypography.fontSizeSmall, fontWeight: FontWeight.w500, color: AppColors.onSurface),
      bodyLarge: TextStyle(color: AppColors.onSurface),
      bodyMedium: TextStyle(color: AppColors.onSurface),
      bodySmall: TextStyle(color: AppColors.onSurfaceVariant),
      labelLarge: TextStyle(color: AppColors.onSurface),
      labelMedium: TextStyle(color: AppColors.onSurface),
      labelSmall: TextStyle(color: AppColors.onSurfaceVariant),
    ),
  );
}
