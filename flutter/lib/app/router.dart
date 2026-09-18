import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/about/about_screen.dart';
import '../features/activities/activities_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/eino/eino_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/more/more_screen.dart';
import '../features/materials/materials_screen.dart';
import '../features/news/media_screen.dart';
import '../features/news/content_detail_screen.dart';
import '../data/models/content_item.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/student/badges_screen.dart';
import '../features/student/student_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/system/system_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/xp/xp_screen.dart';
import '../shared/widgets/trinex_shell.dart';

GoRouter buildRouter({
  required ValueChanged<ThemeMode> onThemeModeChanged,
  required ValueChanged<Locale?> onLocaleChanged,
  required ThemeMode Function() themeMode,
  required Locale? Function() locale,
  required Future<void> startupFuture,
  ValueChanged<String>? onAccentColorChanged,
  String Function()? accentColorId,
  String initialLocation = '/splash',
}) {
  return GoRouter(initialLocation: initialLocation, routes: [
    GoRoute(path: '/splash', builder: (_, _) => SplashScreen(startupFuture: startupFuture)),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ShellRoute(builder: (context, state, child) => TrinexShell(location: state.uri.path, child: child), routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/student', builder: (_, _) => const StudentScreen()),
      GoRoute(path: '/system', builder: (_, _) => const SystemScreen()),
      GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
      GoRoute(path: '/materials', builder: (_, _) => const MaterialsScreen()),
      GoRoute(path: '/news', redirect: (_, _) => '/media'),
      GoRoute(path: '/media', builder: (_, _) => const MediaScreen()),
      GoRoute(path: '/media/detail', builder: (_, state) { final data = state.extra! as Map<String, dynamic>; return ContentDetailScreen(item: data['item'] as ContentItem, type: data['type'] as String); }),
      GoRoute(path: '/news/detail', builder: (_, state) => ContentDetailScreen(item: state.extra! as ContentItem, type: 'news')),
    ]),
    GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
    GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
    GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
    GoRoute(path: '/announcements', builder: (_, _) => const AnnouncementsScreen()),
    GoRoute(path: '/activities', builder: (_, _) => const ActivitiesScreen()),
    GoRoute(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
    GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
    GoRoute(path: '/recent', builder: (_, _) => const RecentScreen()),
    GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
    GoRoute(path: '/xp', builder: (_, _) => const XpScreen()),
    GoRoute(path: '/badges', builder: (_, _) => const BadgesScreen()),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/eino', builder: (_, state) => EinoScreen(source: state.uri.queryParameters['from'] ?? 'home')),
    GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    GoRoute(path: '/settings', builder: (_, _) => SettingsScreen(currentThemeMode: themeMode(), onThemeModeChanged: onThemeModeChanged, locale: locale(), onLocaleChanged: onLocaleChanged, accentColorId: accentColorId?.call(), onAccentColorChanged: onAccentColorChanged)),
  ]);
}
