import 'package:flutter/material.dart';

/// Central visual language for the Association app.
/// Keep spacing, radii and semantic colors here so screens do not invent
/// their own values.
class DesignTokens {
  DesignTokens._();

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;

  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius24 = 24;
  static const double radius32 = 32;

  static const double controlHeight = 52;
  static const double iconButtonSize = 48;
  static const double maxContentWidth = 760;

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 360);
}

class AppColors {
  AppColors._();

  // Association identity orange: warm, energetic and readable on both themes.
  static const Color primary = Color(0xFFF47B20);
  static const Color primaryDark = Color(0xFFFF9848);

  static const Color lightBackground = Color(0xFFF8F7F5);
  static const Color darkBackground = Color(0xFF11100F);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1B1917);

  static const Color success = Color(0xFF2E9B68);
  static const Color warning = Color(0xFFE3A52F);
  static const Color danger = Color(0xFFD95757);
  static const Color info = Color(0xFF4F7CAC);
}

extension DesignThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
