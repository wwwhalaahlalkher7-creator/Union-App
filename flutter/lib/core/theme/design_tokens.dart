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
    required this.nameFr,
    required this.primary,
    required this.primaryDark,
  });

  final String id, nameAr, nameEn, nameFr;

  String localizedName(String languageCode) => switch (languageCode) {
        'fr' => nameFr,
        'en' => nameEn,
        _ => nameAr,
      };
  final Color primary, primaryDark;

  static const defaultColor = AppAccentColor(
    id: 'amber',
    nameAr: 'عمارة وتصميم',
    nameEn: 'Amber / Terracotta',
    nameFr: 'Ambre / Terre cuite',
    primary: Color(0xFFE78100),
    primaryDark: Color(0xFFFFAA25),
  );

  static const presets = <AppAccentColor>[
    AppAccentColor(
      id: 'cyan',
      nameAr: 'أزرق سماوي',
      nameEn: 'Cyan',
      nameFr: 'Cyan',
      primary: Color(0xFF079DDA),
      primaryDark: Color(0xFF24C8FF),
    ),
    AppAccentColor(
      id: 'emerald',
      nameAr: 'أخضر زمردي',
      nameEn: 'Emerald',
      nameFr: 'Émeraude',
      primary: Color(0xFF00A87A),
      primaryDark: Color(0xFF21D9A4),
    ),
    defaultColor,
    AppAccentColor(
      id: 'sapphire',
      nameAr: 'أزرق ياقوتي',
      nameEn: 'Sapphire',
      nameFr: 'Saphir',
      primary: Color(0xFF2865E8),
      primaryDark: Color(0xFF6A8CFF),
    ),
    AppAccentColor(
      id: 'rose',
      nameAr: 'وردي هادئ',
      nameEn: 'Rose',
      nameFr: 'Rose',
      primary: Color(0xFFE85D75),
      primaryDark: Color(0xFFFF8096),
    ),
    AppAccentColor(
      id: 'pink',
      nameAr: 'وردي',
      nameEn: 'Pink',
      nameFr: 'Rose vif',
      primary: Color(0xFFEC4899),
      primaryDark: Color(0xFFFF6FB5),
    ),
    AppAccentColor(
      id: 'orchid',
      nameAr: 'أوركيد',
      nameEn: 'Orchid',
      nameFr: 'Orchidée',
      primary: Color(0xFFA855F7),
      primaryDark: Color(0xFFC084FC),
    ),
    AppAccentColor(
      id: 'lavender',
      nameAr: 'لافندر',
      nameEn: 'Lavender',
      nameFr: 'Lavande',
      primary: Color(0xFF8B7CF6),
      primaryDark: Color(0xFFB0A5FF),
    ),
    AppAccentColor(
      id: 'coral',
      nameAr: 'مرجاني',
      nameEn: 'Coral',
      nameFr: 'Corail',
      primary: Color(0xFFF26B5E),
      primaryDark: Color(0xFFFF8B7F),
    ),
    AppAccentColor(
      id: 'peach',
      nameAr: 'خوخي',
      nameEn: 'Peach',
      nameFr: 'Pêche',
      primary: Color(0xFFF29B7A),
      primaryDark: Color(0xFFFFB69A),
    ),
    AppAccentColor(
      id: 'teal',
      nameAr: 'فيروزي',
      nameEn: 'Teal',
      nameFr: 'Turquoise',
      primary: Color(0xFF0F9D9A),
      primaryDark: Color(0xFF35C9C5),
    ),
    AppAccentColor(
      id: 'violet',
      nameAr: 'بنفسجي',
      nameEn: 'Violet',
      nameFr: 'Violet',
      primary: Color(0xFF7C3AED),
      primaryDark: Color(0xFFA78BFA),
    ),
  ];

  static AppAccentColor fromId(String? id) =>
      presets.firstWhere((c) => c.id == id, orElse: () => defaultColor);
}

class AppColors {
  AppColors._();

  // Dark semantic palette.
  static const background = Color(0xFF070B14);
  static const surface = Color(0xFF101722);
  static const elevated = Color(0xFF172231);
  static const border = Color(0xFF263445);
  static const text = Color(0xFFF6F8FC);
  static const muted = Color(0xFF9AA8BB);

  // Light semantic palette. Screens should use ColorScheme rather than these
  // directly; these values are centralized here for theme construction.
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE1E7EF);
  static const lightText = Color(0xFF172033);
  static const lightMuted = Color(0xFF64748B);

  static const success = Color(0xFF16A67A);
  static const danger = Color(0xFFE55363);
  static const info = Color(0xFF3B82F6);
}

extension DesignThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
