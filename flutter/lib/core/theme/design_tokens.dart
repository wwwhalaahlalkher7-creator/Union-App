import 'package:flutter/material.dart';

class DesignTokens {
  DesignTokens._();
  static const double space4 = 4, space6 = 6, space8 = 8, space12 = 12, space16 = 16, space20 = 20, space24 = 24, space32 = 32, space40 = 40;
  static const double radius12 = 12, radius16 = 16, radius20 = 20, radius24 = 24, radius32 = 32;
  static const double controlHeight = 52, iconButtonSize = 48, maxContentWidth = 860;
  static const Duration fast = Duration(milliseconds: 140), normal = Duration(milliseconds: 220), emphasized = Duration(milliseconds: 360);
}

class AppAccentColor {
  const AppAccentColor({required this.id, required this.nameAr, required this.nameEn, required this.primary, required this.primaryDark});
  final String id, nameAr, nameEn;
  final Color primary, primaryDark;

  static const defaultColor = AppAccentColor(id: 'purple', nameAr: 'أرجواني تقني', nameEn: 'Amethyst', primary: Color(0xFF8B3DFF), primaryDark: Color(0xFFB36BFF));
  static const presets = <AppAccentColor>[
    AppAccentColor(id: 'cyan', nameAr: 'أزرق هندسي', nameEn: 'Cyan', primary: Color(0xFF079DDA), primaryDark: Color(0xFF24C8FF)),
    AppAccentColor(id: 'emerald', nameAr: 'أخضر زمردي', nameEn: 'Emerald', primary: Color(0xFF00A87A), primaryDark: Color(0xFF21D9A4)),
    AppAccentColor(id: 'amber', nameAr: 'عمارة وتصميم', nameEn: 'Amber / Terracotta', primary: Color(0xFFE78100), primaryDark: Color(0xFFFFAA25)),
    AppAccentColor(id: 'sapphire', nameAr: 'كحلي صناعي', nameEn: 'Sapphire', primary: Color(0xFF2865E8), primaryDark: Color(0xFF6A8CFF)),
    defaultColor,
  ];
  static AppAccentColor fromId(String? id) => presets.firstWhere((c) => c.id == id, orElse: () => defaultColor);
}

class AppColors {
  AppColors._();
  static const background = Color(0xFF03081A);
  static const surface = Color(0xFF0D1529);
  static const elevated = Color(0xFF16233A);
  static const border = Color(0xFF1D2B43);
  static const text = Color(0xFFF5F7FF);
  static const muted = Color(0xFF94A3BD);
  static const cyan = Color(0xFF08B8F6);
  static const purple = Color(0xFF8B3DFF);
  static const gold = Color(0xFFF5A400);
  static const success = Color(0xFF00C993);
  static const danger = Color(0xFFF43F67);
  static const navy = Color(0xFF091328);
  static const primary = purple;
  static const primaryDark = Color(0xFFB36BFF);
}

extension DesignThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
