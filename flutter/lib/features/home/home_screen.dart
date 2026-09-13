import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/responsive_content.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/widgets/trinex_brand.dart';
import '../eino/eino_face.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signedIn = false;
  bool _sessionLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    if (!mounted) return;
    setState(() {
      _signedIn = storage.isLoggedIn;
      _sessionLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 70,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          titleSpacing: DesignTokens.space16,
          title: const TrinexLogo(width: 132),
          actions: [
            _HeaderIcon(
              icon: Icons.notifications_none_rounded,
              onTap: () => context.push('/notifications'),
              tooltip: l10n.t('notifications'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 38),
            child: StaggeredFadeIn(
              delay: const Duration(milliseconds: 45),
              children: [
                _WelcomeBlock(signedIn: _signedIn, loaded: _sessionLoaded),
                const SizedBox(height: 16),
                _SearchBar(onTap: () => context.push('/materials')),
                const SizedBox(height: 22),
                _SectionHeader(title: l10n.t('quickAccess'), action: l10n.t('allServices'), onTap: () => context.push('/more')),
                const SizedBox(height: 10),
                _QuickGrid(),
                const SizedBox(height: 24),
                _StudyProgressCard(signedIn: _signedIn),
                const SizedBox(height: 26),
                _SectionHeader(title: l10n.t('latestUpdates'), action: l10n.t('viewAll'), onTap: () => context.push('/news')),
                const SizedBox(height: 10),
                _UpdatesRow(),
                const SizedBox(height: 26),
                const _EinoHero(),
                const SizedBox(height: 24),
                _ServicesCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: .55)),
      ),
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, size: 21)),
    );
  }
}

class _WelcomeBlock extends StatelessWidget {
  const _WelcomeBlock({required this.signedIn, required this.loaded});
  final bool signedIn;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!loaded) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ShimmerBox(width: 190, height: 24, radius: 8), SizedBox(height: 8), ShimmerBox(width: 250, height: 16, radius: 7)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(signedIn ? l10n.t('welcomeBack') : l10n.t('welcome'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(
          signedIn ? l10n.t('studySpaceReady') : l10n.t('homeSubtitle'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      scaleDown: .99,
      child: Container(
        height: 54,
        padding: const EdgeInsetsDirectional.only(start: 15, end: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: cs.outline.withValues(alpha: .55)),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .04), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.t('searchHint'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant))),
            IconButton(tooltip: l10n.t('searchFilters'), onPressed: onTap, icon: Icon(Icons.tune_rounded, size: 20, color: cs.primary)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      );
}

class _QuickGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.menu_book_rounded, l10n.t('materials'), l10n.t('lecturesFiles'), '/materials'),
      (Icons.calendar_month_rounded, l10n.t('schedule'), l10n.t('upcomingClasses'), '/schedule'),
      (Icons.notifications_none_rounded, l10n.t('notifications'), l10n.t('latestAlerts'), '/notifications'),
      (Icons.storefront_rounded, l10n.t('market'), l10n.t('engineeringTools'), '/market'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth < 560;
        final gap = 10.0;
        final cardWidth = twoColumns
            ? (constraints.maxWidth - gap) / 2
            : (constraints.maxWidth - (gap * 3)) / 4;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                height: twoColumns ? 116 : 136,
                child: AppCard(
                  onTap: () => context.push(item.$4),
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(item.$1, color: AppColors.primary, size: 21),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StudyProgressCard extends StatelessWidget {
  const _StudyProgressCard({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => context.push(signedIn ? '/progress' : '/student'),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [cs.surface, cs.surfaceContainerLow]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.auto_graph_rounded, color: AppColors.primary)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(signedIn ? l10n.t('studyProgress') : l10n.t('startStudy'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(signedIn ? l10n.t('studyProgressSubtitle') : l10n.t('startStudySubtitle'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: signedIn ? .68 : 0, minHeight: 6, backgroundColor: cs.surfaceContainerHighest)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _UpdatesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _UpdateCard(icon: Icons.campaign_rounded, title: l10n.t('announcements'), subtitle: l10n.t('announcementsSubtitle'), route: '/announcements'),
          const SizedBox(width: 10),
          _UpdateCard(icon: Icons.article_rounded, title: l10n.t('news'), subtitle: l10n.t('newsSubtitle'), route: '/news'),
          const SizedBox(width: 10),
          _UpdateCard(icon: Icons.event_available_rounded, title: l10n.t('activities'), subtitle: l10n.t('activitiesSubtitle'), route: '/activities'),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.icon, required this.title, required this.subtitle, required this.route});
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 238,
        child: AppCard(
          onTap: () => context.push(route),
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: AppColors.primary)), const Spacer(), Icon(Directionality.of(context) == TextDirection.rtl ? Icons.north_west_rounded : Icons.north_east_rounded, size: 17)]),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _EinoHero extends StatefulWidget {
  const _EinoHero();

  @override
  State<_EinoHero> createState() => _EinoHeroState();
}

class _EinoHeroState extends State<_EinoHero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 186,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [AppColors.navy, Color(0xFF173E5C)])),
        child: Stack(children: [
          const PositionedDirectional(top: -45, end: -25, child: CircuitDecoration(opacity: .45)),
          const PositionedDirectional(end: -4, bottom: -8, child: EinoFace(size: 158, mood: EinoMood.happy)),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 145, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.all(Radius.circular(11))), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19)), const SizedBox(width: 9), Text(l10n.t('eino'), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 10),
              Text(l10n.t('einoCardTitle'), style: TextStyle(color: Colors.white.withValues(alpha: .84), height: 1.35)),
              const Spacer(),
              FilledButton(onPressed: () => context.push('/eino?from=home'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)), child: Text(l10n.t('startChat'))),
            ]),
          ),
        ]),
      ),
    );
    return TickerMode(
      enabled: !reduceMotion,
      child: reduceMotion ? card : AnimatedBuilder(animation: _controller, child: card, builder: (context, child) => Transform.translate(offset: Offset(0, -2 * _controller.value), child: child)),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.t('everythingYouNeed'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _ServiceChip(icon: Icons.emoji_events_rounded, text: l10n.t('achievements'), route: '/achievements'),
          _ServiceChip(icon: Icons.favorite_rounded, text: l10n.t('favorites'), route: '/favorites'),
          _ServiceChip(icon: Icons.history_rounded, text: l10n.t('recentShort'), route: '/recent'),
          _ServiceChip(icon: Icons.settings_rounded, text: l10n.t('settings'), route: '/settings'),
        ]),
      ]),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.icon, required this.text, required this.route});
  final IconData icon;
  final String text;
  final String route;

  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 17), label: Text(text), onPressed: () => context.push(route));
}
