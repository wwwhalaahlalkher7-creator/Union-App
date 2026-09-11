import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../shared/widgets/pressable.dart';
import '../shared/widgets/staggered_fade_in.dart';
import '../features/about/about_screen.dart';
import '../features/activities/activities_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/eino/eino_screen.dart';
import '../features/materials/materials_screen.dart';
import '../features/market/market_screen.dart';
import '../features/news/news_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/student/student_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/xp/xp_screen.dart';
import '../features/student/badges_screen.dart';

GoRouter buildRouter({
  required ValueChanged<ThemeMode> onThemeModeChanged,
  required ValueChanged<Locale?> onLocaleChanged,
  required ThemeMode themeMode,
  required Locale? locale,
}) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
          GoRoute(path: '/materials', builder: (_, _) => const MaterialsScreen()),
          GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
        ],
      ),
      GoRoute(path: '/news', builder: (_, _) => const NewsScreen()),
      GoRoute(path: '/announcements', builder: (_, _) => const AnnouncementsScreen()),
      GoRoute(path: '/activities', builder: (_, _) => const ActivitiesScreen()),
      GoRoute(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/recent', builder: (_, _) => const RecentScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/student', builder: (_, _) => const StudentScreen()),
      GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
      GoRoute(path: '/xp', builder: (_, _) => const XpScreen()),
      GoRoute(path: '/badges', builder: (_, _) => const BadgesScreen()),
      GoRoute(path: '/eino', builder: (_, state) => EinoScreen(source: state.uri.queryParameters['from'] ?? 'home')),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsScreen(
          currentThemeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
          locale: locale,
          onLocaleChanged: onLocaleChanged,
        ),
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  int get currentIndex {
    if (location.startsWith('/schedule')) return 1;
    if (location.startsWith('/materials')) return 2;
    if (location.startsWith('/more')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l10n.t('home')),
      NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month_rounded), label: l10n.t('schedule')),
      NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book_rounded), label: l10n.t('materials')),
      NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded), label: l10n.t('more')),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (widgetChild, animation) => FadeTransition(
            opacity: animation,
            child: widgetChild,
          ),
          child: KeyedSubtree(key: ValueKey(currentIndex), child: child),
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 100,
        child: Stack(clipBehavior: Clip.none, children: [
          Align(alignment: Alignment.bottomCenter, child: NavigationBar(
            selectedIndex: currentIndex,
            destinations: destinations,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              context.go(['/home', '/schedule', '/materials', '/more'][index]);
            },
          )),
          Positioned(top: -8, right: Directionality.of(context) == TextDirection.rtl ? 18 : null, left: Directionality.of(context) == TextDirection.ltr ? 18 : null, child: _EinoFab(onTap: () => context.push('/eino?from=${Uri.encodeComponent(location.startsWith('/materials') ? 'materials' : location.startsWith('/schedule') ? 'schedule' : location.startsWith('/student') ? 'student' : location.startsWith('/progress') ? 'progress' : location.startsWith('/xp') ? 'xp' : location.startsWith('/badges') ? 'badges' : 'home')}'))),
        ]),
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
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: widget.onTap,
      scaleDown: 0.9,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final ring = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Expanding, fading pulse ring behind the FAB.
              Opacity(
                opacity: (1 - ring) * .35,
                child: Transform.scale(
                  scale: 1 + ring * .6,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: primary),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Material(
          elevation: 5,
          shape: const CircleBorder(),
          color: primary,
          child: const Padding(
            padding: EdgeInsets.all(11),
            child: _EinoMiniFace(),
          ),
        ),
      ),
    );
  }
}
class _EinoMiniFace extends StatelessWidget { const _EinoMiniFace(); @override Widget build(BuildContext context) => const SizedBox(width: 36, height: 36, child: CustomPaint(painter: _MiniPainter())); }
class _MiniPainter extends CustomPainter {
  const _MiniPainter();
  @override void paint(Canvas c, Size s) { final p=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=2; final o=Offset(s.width/2,s.height/2); final r=s.width*.34; c.drawCircle(o,r,p); c.drawCircle(Offset(o.dx-r*.4,o.dy-r*.1),r*.08,p); c.drawCircle(Offset(o.dx+r*.4,o.dy-r*.1),r*.08,p); final m=Path()..moveTo(o.dx-r*.22,o.dy+r*.22)..quadraticBezierTo(o.dx,o.dy+r*.4,o.dx+r*.22,o.dy+r*.22); c.drawPath(m,p); }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.storefront_outlined, 'سوق الأدوات الهندسية', '/market'),
      (Icons.school_outlined, l10n.t('student'), '/student'),
      (Icons.insights_rounded, 'تقدمي الدراسي', '/progress'),
      (Icons.auto_awesome, 'Eino', '/eino'),
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

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(l10n.t('more')),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              StaggeredFadeIn(
                delay: const Duration(milliseconds: 28),
                children: [
                  for (final item in items) ...[
                    Pressable(
                      onTap: () => context.push(item.$3),
                      scaleDown: 0.98,
                      child: Card(
                        child: ListTile(
                          leading: Icon(item.$1, color: Theme.of(context).colorScheme.primary),
                          title: Text(item.$2),
                          trailing: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
