import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

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
      elevation: 0,
      color: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.buttonPaddingHorizontal, vertical: AppSpacing.buttonPaddingVertical),
        minimumSize: const Size(0, AppSpacing.space10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.buttonPaddingHorizontal, vertical: AppSpacing.buttonPaddingVertical),
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
      selectedLabelStyle: TextStyle(fontSize: AppTypography.fontSizeXSmall, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: AppTypography.fontSizeXSmall),
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
      titleLarge: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: AppColors.onSurface),
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
