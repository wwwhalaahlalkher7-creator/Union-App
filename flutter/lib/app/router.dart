import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/settings/student_account_screen.dart';
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
import '../features/learning_events/learning_events_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/student/badges_screen.dart';
import '../features/student/student_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/xp/xp_screen.dart';
import '../shared/widgets/trinex_shell.dart';
import '../shared/widgets/student_access_gate.dart';


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
    GoRoute(path: '/forgot-password', builder: (_, state) => ForgotPasswordScreen(initialStudentNumber: state.uri.queryParameters['studentNumber'])),
    ShellRoute(builder: (context, state, child) => TrinexShell(location: state.uri.path, child: child), routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/student', builder: (_, _) => const StudentScreen()),
      GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
      GoRoute(path: '/materials', builder: (_, _) => const MaterialsScreen()),
      GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
      GoRoute(path: '/media', builder: (_, state) {
        final rawTab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
        final initialTab = rawTab.clamp(0, 2).toInt();
        return MediaScreen(initialTab: initialTab);
      }),
      GoRoute(path: '/media/detail', builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic> && extra['item'] is ContentItem && extra['type'] is String) {
          return ContentDetailScreen(item: extra['item'] as ContentItem, type: extra['type'] as String);
        }
        return const MediaScreen();
      }),
    ]),
    GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
    GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
    GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
    GoRoute(path: '/recent', builder: (_, _) => const RecentScreen()),
    GoRoute(path: '/xp', builder: (_, _) => const StudentAccessGate(child: XpScreen())),
    GoRoute(path: '/badges', builder: (_, _) => const StudentAccessGate(child: BadgesScreen())),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/learning-events', builder: (_, _) => const StudentAccessGate(child: LearningEventsScreen())),
    GoRoute(path: '/learning-events/:id', builder: (_, state) => StudentAccessGate(child: LearningEventRouteScreen(eventId: state.pathParameters['id'] ?? ''))),
    GoRoute(path: '/eino', builder: (_, state) => EinoScreen(source: state.uri.queryParameters['from'] ?? 'home')),
    GoRoute(path: '/account-settings', builder: (_, _) => const StudentAccountScreen()),
    GoRoute(path: '/settings', builder: (_, _) => SettingsScreen(currentThemeMode: themeMode(), onThemeModeChanged: onThemeModeChanged, locale: locale(), onLocaleChanged: onLocaleChanged, accentColorId: accentColorId?.call(), onAccentColorChanged: onAccentColorChanged)),
  ]);
}
