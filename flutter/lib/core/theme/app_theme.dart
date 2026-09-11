import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primary;
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? const Color(0xFFF4F0EC) : const Color(0xFF211E1B),
      surfaceContainerLowest: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      surfaceContainerLow: isDark ? const Color(0xFF161412) : const Color(0xFFF3F0EC),
      surfaceContainerHighest: isDark ? const Color(0xFF292522) : const Color(0xFFEDE8E2),
      outline: isDark ? const Color(0xFF4A433E) : const Color(0xFFD8D0C8),
      error: AppColors.danger,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme, fontFamily: 'sans');
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      splashFactory: InkSparkle.splashFactory,
      splashColor: primary.withValues(alpha: .10),
      highlightColor: primary.withValues(alpha: .04),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _FadeThroughTransitionsBuilder(),
        TargetPlatform.iOS: _FadeThroughTransitionsBuilder(),
        TargetPlatform.linux: _FadeThroughTransitionsBuilder(),
        TargetPlatform.macOS: _FadeThroughTransitionsBuilder(),
        TargetPlatform.windows: _FadeThroughTransitionsBuilder(),
      }),
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.4),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.25),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: DesignTokens.space16,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        indicatorColor: primary.withValues(alpha: .16),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size.square(DesignTokens.iconButtonSize), foregroundColor: scheme.onSurface)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(0, DesignTokens.controlHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20, vertical: DesignTokens.space12),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, DesignTokens.controlHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        side: BorderSide(color: scheme.outline),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16), borderSide: BorderSide(color: primary.withValues(alpha: .55), width: 1.5)),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius20), side: BorderSide(color: scheme.outline.withValues(alpha: .35))),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        side: BorderSide(color: scheme.outline.withValues(alpha: .4)),
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: .25), space: 1),
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);
}

class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final fadeOut = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: FadeTransition(opacity: Tween<double>(begin: 1, end: 0).animate(fadeOut), child: ScaleTransition(scale: Tween<double>(begin: .98, end: 1).animate(curved), child: child)),
    );
  }
}
