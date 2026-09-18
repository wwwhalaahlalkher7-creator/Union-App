import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark({AppAccentColor accent = AppAccentColor.defaultColor}) {
    final scheme = ColorScheme.fromSeed(seedColor: accent.primary, brightness: Brightness.dark).copyWith(
      primary: accent.primary,
      onPrimary: Colors.white,
      secondary: accent.primaryDark,
      onSecondary: Colors.white,
      tertiary: accent.primary,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.elevated,
      outline: AppColors.border,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData light({AppAccentColor accent = AppAccentColor.defaultColor}) {
    final scheme = ColorScheme.fromSeed(seedColor: accent.primary, brightness: Brightness.light).copyWith(primary: accent.primary, onPrimary: Colors.white, secondary: accent.primaryDark, onSecondary: Colors.white, tertiary: accent.primary, onTertiary: Colors.white);
    return _base(scheme, Brightness.light);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness, visualDensity: VisualDensity.standard);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? AppColors.background : const Color(0xFFF6F8FC),
      textTheme: base.textTheme.apply(fontSizeFactor: .95, bodyColor: dark ? AppColors.text : const Color(0xFF172033), displayColor: dark ? AppColors.text : const Color(0xFF172033)),
      appBarTheme: AppBarTheme(backgroundColor: dark ? AppColors.background : Colors.white, foregroundColor: scheme.onSurface, surfaceTintColor: Colors.transparent, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: dark ? AppColors.surface : Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: dark ? AppColors.border : const Color(0xFFE2E8F0)))),
      dividerTheme: DividerThemeData(color: dark ? AppColors.border : const Color(0xFFE2E8F0), thickness: 1),
      buttonTheme: ButtonThemeData(height: 42, minWidth: 0, buttonColor: scheme.primary),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? AppColors.surface : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? AppColors.border : const Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? AppColors.border : const Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.5))),
    );
  }
}
