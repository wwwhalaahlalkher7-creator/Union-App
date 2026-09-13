import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/design_tokens.dart';
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

GoRouter buildRouter({required ValueChanged<ThemeMode> onThemeModeChanged, required ValueChanged<Locale?> onLocaleChanged, required ThemeMode themeMode, required Locale? locale}) => GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/materials', builder: (_, _) => const MaterialsScreen()),
        GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        GoRoute(path: '/student', builder: (_, _) => const StudentScreen()),
      ],
    ),
    GoRoute(path: '/news', builder: (_, _) => const NewsScreen()),
    GoRoute(path: '/announcements', builder: (_, _) => const AnnouncementsScreen()),
    GoRoute(path: '/activities', builder: (_, _) => const ActivitiesScreen()),
    GoRoute(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
    GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
    GoRoute(path: '/recent', builder: (_, _) => const RecentScreen()),
    GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
    GoRoute(path: '/xp', builder: (_, _) => const XpScreen()),
    GoRoute(path: '/badges', builder: (_, _) => const BadgesScreen()),
    GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
    GoRoute(path: '/eino', builder: (_, state) => EinoScreen(source: state.uri.queryParameters['from'] ?? 'home')),
    GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    GoRoute(path: '/settings', builder: (_, _) => SettingsScreen(currentThemeMode: themeMode, onThemeModeChanged: onThemeModeChanged, locale: locale, onLocaleChanged: onLocaleChanged)),
  ],
);

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
    final labels = [l10n.t('home'), l10n.t('materials'), l10n.t('schedule'), l10n.t('notifications'), l10n.t('student')];
    final icons = [Icons.home_outlined, Icons.menu_book_outlined, Icons.calendar_month_outlined, Icons.notifications_none_rounded, Icons.person_outline_rounded];
    final selectedIcons = [Icons.home_rounded, Icons.menu_book_rounded, Icons.calendar_month_rounded, Icons.notifications_rounded, Icons.person_rounded];
    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false, child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: KeyedSubtree(key: ValueKey(location), child: child))),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: SizedBox(
            height: 78,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(25), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .55)), boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 8))]),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: currentIndex,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [for (var i=0;i<5;i++) NavigationDestination(icon: Icon(icons[i]), selectedIcon: Icon(selectedIcons[i]), label: labels[i])],
                  onDestinationSelected: (index) { HapticFeedback.selectionClick(); context.go(['/home','/materials','/schedule','/notifications','/student'][index]); },
                ),
              )),
              PositionedDirectional(top: -24, start: 0, end: 0, child: Center(child: _EinoFab(onTap: () => context.push('/eino?from=$_einoSource')))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EinoFab extends StatefulWidget { const _EinoFab({required this.onTap}); final VoidCallback onTap; @override State<_EinoFab> createState()=>_EinoFabState(); }
class _EinoFabState extends State<_EinoFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse=AnimationController(vsync:this,duration:const Duration(seconds:2))..repeat();
  @override void dispose(){_pulse.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>GestureDetector(
    onTap: widget.onTap,
    child: AnimatedBuilder(animation:_pulse,builder:(context,_) { final ring=_pulse.value; return SizedBox(width:66,height:66,child:Stack(alignment:Alignment.center,children:[Opacity(opacity:(1-ring)*.25,child:Transform.scale(scale:1+ring*.42,child:Container(width:60,height:60,decoration:const BoxDecoration(shape:BoxShape.circle,color:AppColors.primary)))),Container(width:60,height:60,padding:const EdgeInsets.all(3),decoration:BoxDecoration(shape:BoxShape.circle,color:AppColors.primary,border:Border.all(color:Colors.white,width:3),boxShadow:[BoxShadow(color:AppColors.navy.withValues(alpha:.25),blurRadius:12,offset:const Offset(0,5))]),child:ClipOval(child:Image.asset('assets/images/eino.png',fit:BoxFit.cover))),])); }),
  );
}
