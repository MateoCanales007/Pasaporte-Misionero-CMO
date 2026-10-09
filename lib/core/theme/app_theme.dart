import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Tema único de la aplicación. Tipografía grande, botones altos y alto
/// contraste, manteniendo la identidad azul marino y dorado del CMO.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      onSecondary: AppColors.onOrange,
      tertiary: AppColors.yellow,
      onTertiary: AppColors.navy,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    const textTheme = TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.navy),
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navy),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
      titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      titleSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 18, height: 1.4, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 17, height: 1.4, color: AppColors.textPrimary),
      bodySmall: TextStyle(fontSize: 15, height: 1.35, color: AppColors.textSecondary),
      labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
      labelMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );

    final roundedShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSmall));
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md);
    const buttonMinSize = Size(64, AppSpacing.touchTarget);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white, size: 28),
        // Franja naranja del logo bajo la barra superior.
        shape: Border(bottom: BorderSide(color: AppColors.orange, width: 4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: roundedShape,
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.onOrange,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: roundedShape,
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: roundedShape,
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.navy,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        extendedTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        extendedSizeConstraints: BoxConstraints(minHeight: 60, minWidth: 60),
        extendedIconLabelSpacing: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 18),
        labelStyle: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(fontSize: 18, color: AppColors.navy),
        hintStyle: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
        helperStyle: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        errorStyle: const TextStyle(fontSize: 15, color: AppColors.error),
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.yellow,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 14,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.navy : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 28,
            color: states.contains(WidgetState.selected) ? AppColors.navy : AppColors.textSecondary,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(fontSize: 17, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.navy : null,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        subtitleTextStyle: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        iconColor: AppColors.navy,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.yellow : Colors.white,
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.navy),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.orange),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(fontSize: 16, color: Colors.white),
        waitDuration: Duration(milliseconds: 400),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
