import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark({AppAccentColor accent = AppAccentColor.defaultColor}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent.primaryDark,
      onPrimary: Colors.white,
      secondary: accent.primary,
      onSecondary: Colors.white,
      tertiary: accent.primaryDark,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.elevated,
      outline: AppColors.border,
      outlineVariant: AppColors.border.withValues(alpha: .72),
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData light({AppAccentColor accent = AppAccentColor.defaultColor}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: accent.primary,
      onPrimary: Colors.white,
      secondary: accent.primaryDark,
      onSecondary: Colors.white,
      tertiary: accent.primary,
      onTertiary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorder,
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
    );

    final text = base.textTheme.copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.6),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.3),
      titleLarge: const TextStyle(fontWeight: FontWeight.w800),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: const TextStyle(height: 1.5),
      bodyMedium: const TextStyle(height: 1.45),
      labelLarge: const TextStyle(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      scaffoldBackgroundColor:
          dark ? AppColors.background : AppColors.lightBackground,
      textTheme: text.apply(
        bodyColor: dark ? AppColors.text : AppColors.lightText,
        displayColor: dark ? AppColors.text : AppColors.lightText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.background : AppColors.lightBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: dark ? AppColors.surface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          side: BorderSide(
            color: dark ? AppColors.border : AppColors.lightBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? AppColors.border : AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, DesignTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, DesignTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, DesignTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.surface : AppColors.lightSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: BorderSide(
            color: dark ? AppColors.border : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: BorderSide(
            color: dark ? AppColors.border : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
      ),
    );
  }
}
