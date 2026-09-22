import 'package:flutter/material.dart';

/// Single source of truth for the visual language.
///
/// Keep these values semantic and stable so screens do not invent their own
/// spacing/radius values. This also makes future visual refreshes predictable.
class DesignTokens {
  DesignTokens._();

  // 4pt base grid.
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

  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius24 = 24;

  static const double controlHeight = 48;
  static const double iconButtonSize = 48;
  static const double maxContentWidth = 920;

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 360);
}

class AppAccentColor {
  const AppAccentColor({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.primary,
    required this.primaryDark,
  });

  final String id, nameAr, nameEn;
  final Color primary, primaryDark;

  static const defaultColor = AppAccentColor(
    id: 'amber',
    nameAr: 'عمارة وتصميم',
    nameEn: 'Amber / Terracotta',
    primary: Color(0xFFE78100),
    primaryDark: Color(0xFFFFAA25),
  );

  static const presets = <AppAccentColor>[
    AppAccentColor(
      id: 'cyan',
      nameAr: 'أزرق هندسي',
      nameEn: 'Cyan',
      primary: Color(0xFF079DDA),
      primaryDark: Color(0xFF24C8FF),
    ),
    AppAccentColor(
      id: 'emerald',
      nameAr: 'أخضر زمردي',
      nameEn: 'Emerald',
      primary: Color(0xFF00A87A),
      primaryDark: Color(0xFF21D9A4),
    ),
    defaultColor,
    AppAccentColor(
      id: 'sapphire',
      nameAr: 'كحلي صناعي',
      nameEn: 'Sapphire',
      primary: Color(0xFF2865E8),
      primaryDark: Color(0xFF6A8CFF),
    ),
  ];

  static AppAccentColor fromId(String? id) =>
      presets.firstWhere((c) => c.id == id, orElse: () => defaultColor);
}

class AppColors {
  AppColors._();

  static const background = Color(0xFF070B14);
  static const surface = Color(0xFF101722);
  static const elevated = Color(0xFF172231);
  static const border = Color(0xFF263445);
  static const text = Color(0xFFF6F8FC);
  static const muted = Color(0xFF9AA8BB);

  static const success = Color(0xFF16A67A);
  static const danger = Color(0xFFE55363);
  static const info = Color(0xFF3B82F6);
}

extension DesignThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
