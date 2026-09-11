import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/storage/auth_storage.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../eino/eino_face.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signedIn = false;
  @override void initState() { super.initState(); _loadSession(); }
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    if (mounted) setState(() => _signedIn = storage.isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[
      StaggeredFadeIn(children: [
        Text(_signedIn ? 'أهلًا بك من جديد 👋' : l10n.t('welcome'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_signedIn ? 'هذه مساحتك الدراسية المخصصة.' : 'أخبار الرابطة وخدماتها ومعلومات الكلية في مكان واحد.', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 18),
        _EinoBanner(cs: cs),
        const SizedBox(height: 22),
        AppSection(title: 'مستجدات الرابطة', action: TextButton(onPressed: () => context.push('/news'), child: Text(l10n.t('seeMore'))), child: Row(children: [
          Expanded(child: AppCard(onTap: () => context.push('/news'), child: const _QuickTile(icon: Icons.article_outlined, title: 'الأخبار', subtitle: 'تابع آخر المستجدات'))),
          const SizedBox(width: 10),
          Expanded(child: AppCard(onTap: () => context.push('/announcements'), child: const _QuickTile(icon: Icons.campaign_outlined, title: 'الإعلانات', subtitle: 'تنبيهات مهمة'))),
        ])),
        const SizedBox(height: 22),
        AppSection(title: 'خدمات الرابطة', child: Column(children: [
          _ServiceTile(icon: Icons.event_outlined, title: l10n.t('activities'), subtitle: 'أنشطة وفعاليات الكلية', onTap: () => context.push('/activities')),
          _ServiceTile(icon: Icons.emoji_events_outlined, title: l10n.t('achievements'), subtitle: 'إنجازات الرابطة', onTap: () => context.push('/achievements')),
          _ServiceTile(icon: Icons.school_outlined, title: l10n.t('student'), subtitle: _signedIn ? 'ملفك الدراسي وإحصاءاتك' : 'سجّل للدخول إلى تجربتك الشخصية', onTap: () => context.push('/student')),
        ])),
        const SizedBox(height: 22),
        if (_signedIn) AppSection(title: 'مساحتك الدراسية', subtitle: 'محتوى مرتبط بتخصصك وفصلك', child: Row(children: [
          Expanded(child: AppButton(label: l10n.t('materials'), icon: Icons.menu_book_rounded, onPressed: () => context.go('/materials'))),
          const SizedBox(width: 10),
          Expanded(child: AppButton(label: l10n.t('schedule'), icon: Icons.calendar_month_rounded, onPressed: () => context.go('/schedule'), secondary: true)),
        ])) else AppCard(child: Row(children: [
          const Icon(Icons.lock_outline_rounded, size: 30),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('افتح تجربتك الدراسية', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('المواد والجدول متاحان بعد تسجيل الطالب.')])),
          const SizedBox(width: 8),
          TextButton(onPressed: () => context.push('/student'), child: const Text('دخول')),
        ])),
      ]),
    ];
    return CustomScrollView(slivers: [
      SliverAppBar(pinned: true, title: Text(l10n.t('appName')), actions: [
        IconButton(tooltip: l10n.t('notifications'), onPressed: () => context.push('/notifications'), icon: const Icon(Icons.notifications_none_rounded)),
      ]),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ]);
  }
}

class _QuickTile extends StatelessWidget { const _QuickTile({required this.icon, required this.title, required this.subtitle}); final IconData icon; final String title, subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)]); }
class _ServiceTile extends StatelessWidget { const _ServiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap}); final IconData icon; final String title, subtitle; final VoidCallback onTap; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.chevron_left_rounded)]))); }

class _EinoBanner extends StatefulWidget { const _EinoBanner({required this.cs}); final ColorScheme cs; @override State<_EinoBanner> createState() => _EinoBannerState(); }
class _EinoBannerState extends State<_EinoBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    const content = Row(
      children: [
        EinoFace(size: 70),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إينو', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('مساعدك داخل الرابطة للدراسة والخدمات والأسئلة العامة.', style: TextStyle(height: 1.35)),
              SizedBox(height: 8),
              Text('ابدأ المحادثة ←', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );

    Widget card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: .16)),
      ),
      child: content,
    );

    if (!reduceMotion) {
      card = AnimatedBuilder(
        animation: _controller,
        child: content,
        builder: (context, child) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: .12 + _controller.value * .08),
                cs.primary.withValues(alpha: .03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.primary.withValues(alpha: .16)),
          ),
          child: child,
        ),
      );
    }

    return Pressable(
      onTap: () => context.push('/eino?from=home'),
      scaleDown: .98,
      child: card,
    );
  }
}
