import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pressable.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    if (mounted) setState(() => _signedIn = storage.isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 68,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          title: const TrinexLogo(width: 138),
          actions: [
            _HeaderIcon(
              icon: Icons.notifications_none_rounded,
              onTap: () => context.push('/notifications'),
              tooltip: l10n.t('notifications'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              StaggeredFadeIn(
                delay: const Duration(milliseconds: 40),
                children: [
                  _HeroHeader(signedIn: _signedIn),
                  const SizedBox(height: 14),
                  _SearchBar(onTap: () => context.push('/materials')),
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'الوصول السريع', action: 'كل الخدمات', onTap: () => context.push('/more')),
                  const SizedBox(height: 10),
                  _QuickGrid(),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'دراستك في مكان واحد', action: 'استكشف', onTap: () => context.push(_signedIn ? '/materials' : '/student')),
                  const SizedBox(height: 10),
                  _StudyCard(signedIn: _signedIn),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'آخر المستجدات', action: 'عرض الكل', onTap: () => context.push('/news')),
                  const SizedBox(height: 10),
                  _UpdatesRow(),
                  const SizedBox(height: 24),
                  _EinoHero(),
                  const SizedBox(height: 24),
                  _ServicesCard(),
                ],
              ),
            ]),
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
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .55)),
        ),
        child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, size: 22)),
      );
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        constraints: const BoxConstraints(minHeight: 190),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.navy, Color(0xFF153C5A)],
          ),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Stack(
          children: [
            const PositionedDirectional(top: -28, end: -30, child: CircuitDecoration(opacity: .45)),
            PositionedDirectional(
              top: 20,
              end: 20,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(17)),
                child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 28),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(signedIn ? 'أهلًا بك من جديد 👋' : 'مرحبًا بك في TRINEX 👋', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  Text(
                    signedIn ? 'مساحتك الدراسية أصبحت جاهزة لك.' : 'منصة الهندسة والعمارة والتقنية في مكان واحد.',
                    style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      _HeroStat(icon: Icons.menu_book_rounded, label: 'المواد'),
                      SizedBox(width: 8),
                      _HeroStat(icon: Icons.calendar_month_rounded, label: 'الجدول'),
                      SizedBox(width: 8),
                      _HeroStat(icon: Icons.auto_awesome_rounded, label: 'إينو'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withValues(alpha: .08))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 17, color: AppColors.primaryDark), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))]),
        ),
      );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scaleDown: .99,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .6)),
          ),
          child: Row(children: [
            Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text('ابحث عن المواد، الجداول والخدمات...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Icon(Icons.tune_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
          ]),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Text(action)),
      ]);
}

class _QuickGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.menu_book_rounded, 'المواد', 'محاضرات وملفات', '/materials'),
      (Icons.calendar_month_rounded, 'الجدول', 'حصصك القادمة', '/schedule'),
      (Icons.notifications_none_rounded, 'الإشعارات', 'آخر التنبيهات', '/notifications'),
      (Icons.storefront_rounded, 'المتجر', 'أدوات هندسية', '/market'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.75),
      itemBuilder: (context, index) {
        final item = items[index];
        return AppCard(
          onTap: () => context.push(item.$4),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: index == 0 ? AppColors.primary.withValues(alpha: .12) : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(13)), child: Icon(item.$1, color: index == 0 ? AppColors.primary : AppColors.navy, size: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(item.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)])),
          ]),
        );
      },
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(signedIn ? '/progress' : '/student'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [cs.surface, cs.surfaceContainerLow])),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.auto_graph_rounded, color: AppColors.primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(signedIn ? 'تابع تقدمك الدراسي' : 'افتح تجربتك الدراسية', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text(signedIn ? 'تخصصك وموادك والـ XP في لوحة واحدة.' : 'سجّل دخولك للوصول إلى المواد والجدول والتقدم.', style: Theme.of(context).textTheme.bodySmall)])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 17),
        ]),
      ),
    );
  }
}

class _UpdatesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 128,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            const _UpdateCard(icon: Icons.campaign_rounded, title: 'الإعلانات', subtitle: 'تنبيهات مهمة من الرابطة', route: '/announcements'),
            const SizedBox(width: 10),
            const _UpdateCard(icon: Icons.article_rounded, title: 'الأخبار', subtitle: 'آخر أخبار الكلية والرابطة', route: '/news'),
            const SizedBox(width: 10),
            const _UpdateCard(icon: Icons.event_available_rounded, title: 'الأنشطة', subtitle: 'فعاليات ومبادرات جديدة', route: '/activities'),
          ],
        ),
      );
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.icon, required this.title, required this.subtitle, required this.route});
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 235,
        child: AppCard(
          onTap: () => context.push(route),
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: AppColors.primary)), const Spacer(), const Icon(Icons.north_east_rounded, size: 17)]),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _EinoHero extends StatefulWidget {
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 180,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [Color(0xFF0D2B45), Color(0xFF173E5C)])),
        child: Stack(children: [
          const PositionedDirectional(top: -45, end: -25, child: CircuitDecoration(opacity: .45)),
          const PositionedDirectional(end: 0, bottom: -6, child: EinoFace(size: 155, mood: EinoMood.happy)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 135, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.all(Radius.circular(11))), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19)), const SizedBox(width: 9), const Text('إينو', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 10),
              Text('مساعدك الذكي داخل TRINEX', style: TextStyle(color: Colors.white.withValues(alpha: .82), height: 1.35)),
              const Spacer(),
              FilledButton(onPressed: () => context.push('/eino?from=home'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('ابدأ المحادثة')),
            ]),
          ),
        ]),
      ),
    );
    if (reduceMotion) return card;
    return AnimatedBuilder(animation: _controller, child: card, builder: (context, child) => Transform.translate(offset: Offset(0, -2 * _controller.value), child: child));
  }
}

class _ServicesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const AppCard(
        padding: EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('كل ما تحتاجه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _ServiceChip(icon: Icons.emoji_events_rounded, text: 'الإنجازات', route: '/achievements'),
            _ServiceChip(icon: Icons.favorite_rounded, text: 'المفضلة', route: '/favorites'),
            _ServiceChip(icon: Icons.history_rounded, text: 'الأخيرة', route: '/recent'),
            _ServiceChip(icon: Icons.settings_rounded, text: 'الإعدادات', route: '/settings'),
          ]),
        ]),
      );
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.icon, required this.text, required this.route});
  final IconData icon;
  final String text;
  final String route;

  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 17), label: Text(text), onPressed: () => context.push(route));
}
