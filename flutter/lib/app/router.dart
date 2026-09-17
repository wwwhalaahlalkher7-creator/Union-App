import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/design_tokens.dart';
import '../features/about/about_screen.dart';
import '../features/activities/activities_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/eino/eino_face.dart';
import '../features/eino/eino_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/materials/materials_screen.dart';
import '../features/news/news_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/student/badges_screen.dart';
import '../features/student/student_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/xp/xp_screen.dart';
import '../shared/widgets/pressable.dart';
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
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => SplashScreen(startupFuture: startupFuture)),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/materials', builder: (_, _) => const StudentAccessGate(child: MaterialsScreen())),
          GoRoute(path: '/schedule', builder: (_, _) => const StudentAccessGate(child: ScheduleScreen())),
          GoRoute(path: '/notifications', builder: (_, _) => const StudentAccessGate(child: NotificationsScreen())),
          GoRoute(path: '/student', builder: (_, _) => const StudentScreen()),
        ],
      ),
      GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
      GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
      GoRoute(path: '/news', builder: (_, _) => const NewsScreen()),
      GoRoute(path: '/announcements', builder: (_, _) => const AnnouncementsScreen()),
      GoRoute(path: '/activities', builder: (_, _) => const ActivitiesScreen()),
      GoRoute(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/recent', builder: (_, _) => const RecentScreen()),
      GoRoute(path: '/progress', builder: (_, _) => const StudentAccessGate(child: ProgressScreen())),
      GoRoute(path: '/xp', builder: (_, _) => const StudentAccessGate(child: XpScreen())),
      GoRoute(path: '/badges', builder: (_, _) => const StudentAccessGate(child: BadgesScreen())),
      GoRoute(path: '/eino', builder: (_, state) => EinoScreen(source: state.uri.queryParameters['from'] ?? 'home')),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsScreen(
          currentThemeMode: themeMode(),
          onThemeModeChanged: onThemeModeChanged,
          locale: locale(),
          onLocaleChanged: onLocaleChanged,
          accentColorId: accentColorId?.call(),
          onAccentColorChanged: onAccentColorChanged,
        ),
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  int get currentIndex {
    if (location.startsWith('/materials')) return 1;
    if (location.startsWith('/schedule')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/student')) return 4;
    return 0;
  }

  String get _einoSource {
    if (location.startsWith('/materials')) return 'materials';
    if (location.startsWith('/schedule')) return 'schedule';
    if (location.startsWith('/student')) return 'student';
    if (location.startsWith('/notifications')) return 'notifications';
    return 'home';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l10n.t('home')),
      NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book_rounded), label: l10n.t('materials')),
      NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month_rounded), label: l10n.t('schedule')),
      NavigationDestination(icon: const Icon(Icons.notifications_none_rounded), selectedIcon: const Icon(Icons.notifications_rounded), label: l10n.t('notifications')),
      NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: l10n.t('student')),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: _EinoFab(onTap: () => context.push('/eino?from=$_einoSource')),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          context.go(['/home', '/materials', '/schedule', '/notifications', '/student'][index]);
        },
      ),
    );
  }
}

class _EinoFab extends StatefulWidget {
  const _EinoFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_EinoFab> createState() => _EinoFabState();
}

class _EinoFabState extends State<_EinoFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TickerMode(
      enabled: !reduceMotion,
      child: Pressable(
        onTap: widget.onTap,
        scaleDown: .91,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final ring = reduceMotion ? 0.0 : _pulse.value;
            return SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: (1 - ring) * .25,
                    child: Transform.scale(
                      scale: 1 + ring * .45,
                      child: Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle, color: primary)),
                    ),
                  ),
                  Material(
                    elevation: 6,
                    shadowColor: AppColors.navy.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    color: Theme.of(context).colorScheme.surface,
                    child: Container(
                      width: 54,
                      height: 54,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primary, width: 2),
                      ),
                      child: const EinoFace(size: 48, mood: EinoMood.happy),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.handyman_outlined, l10n.t('toolsTitle'), '/tools'),
      (Icons.storefront_outlined, l10n.t('market'), '/market'),
      (Icons.school_outlined, l10n.t('student'), '/student'),
      (Icons.insights_rounded, l10n.t('studyProgress'), '/progress'),
      (Icons.auto_awesome, l10n.t('eino'), '/eino'),
      (Icons.article_outlined, l10n.t('news'), '/news'),
      (Icons.campaign_outlined, l10n.t('announcements'), '/announcements'),
      (Icons.event_outlined, l10n.t('activities'), '/activities'),
      (Icons.emoji_events_outlined, l10n.t('achievements'), '/achievements'),
      (Icons.favorite_border, l10n.t('favorites'), '/favorites'),
      (Icons.history, l10n.t('recent'), '/recent'),
      (Icons.notifications_none, l10n.t('notifications'), '/notifications'),
      (Icons.settings_outlined, l10n.t('settings'), '/settings'),
      (Icons.info_outline, l10n.t('about'), '/about'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('more'))),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Pressable(
            onTap: () => context.push(item.$3),
            scaleDown: .985,
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)), child: Icon(item.$1, color: AppColors.primary)),
                title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
              ),
            ),
          );
        },
      ),
    );
  }
}
