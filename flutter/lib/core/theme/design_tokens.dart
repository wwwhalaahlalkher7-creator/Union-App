import 'package:flutter/material.dart';

/// TRINEX visual language. Keep shared spacing, radii and brand colors here.
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

  // TRINEX brand palette from the approved visual direction.
  static const Color primary = Color(0xFFF47B20);
  static const Color primaryDark = Color(0xFFFF9848);
  static const Color navy = Color(0xFF0D2B45);
  static const Color blue = Color(0xFF4E6B8A);
  static const Color background = Color(0xFFF5F7FA);
  static const Color text = Color(0xFF1F2937);
  static const Color border = Color(0xFFDDE4EA);

  static const Color lightBackground = background;
  static const Color darkBackground = Color(0xFF081D2F);
  static const Color lightSurface = Colors.white;
  static const Color darkSurface = Color(0xFF102E46);

  static const Color success = Color(0xFF2E9B68);
  static const Color warning = Color(0xFFE3A52F);
  static const Color danger = Color(0xFFD95757);
  static const Color info = blue;
}

extension DesignThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
