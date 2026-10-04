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
        toolbarHeight: 60,
        titleSpacing: 4,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 23),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 23),
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.25,
        ),
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
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
        errorStyle: TextStyle(
          color: scheme.error,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
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
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        contentTextStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? AppColors.surface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius24),
        ),
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.surface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? AppColors.surface : AppColors.lightSurface,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: dark ? AppColors.background : AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: selected ? 23 : 22);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        strokeCap: StrokeCap.round,
        circularTrackColor: scheme.surfaceContainerHighest,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: dark ? AppColors.elevated : AppColors.lightText,
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
