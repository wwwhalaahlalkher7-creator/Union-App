import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_version.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/eino/eino_face.dart';

class TrinexShell extends StatefulWidget {
  const TrinexShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  @override State<TrinexShell> createState() => _TrinexShellState();
}

class _TrinexShellState extends State<TrinexShell> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override void dispose() { _pulse.dispose(); super.dispose(); }

  int get index {
    if (widget.location.startsWith('/student')) return 0;
    if (widget.location.startsWith('/system')) return 1;
    if (widget.location.startsWith('/schedule')) return 2;
    if (widget.location.startsWith('/materials')) return 3;
    if (widget.location.startsWith('/news')) return 4;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.background : const Color(0xFFF5F7FC),
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _TopHeader(),
            _MainNav(selected: index),
            Expanded(child: Stack(children: [
              widget.child,
              PositionedDirectional(end: 18, bottom: 18, child: _EinoButton(animation: _pulse)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 600;
        final button = compact ? 40.0 : 48.0;
        final avatar = compact ? 42.0 : 48.0;
        final logo = compact ? 54.0 : 62.0;
        final gap = compact ? 5.0 : 10.0;
        return Row(children: [
          _HeaderIcon(icon: Icons.logout_rounded, color: AppColors.danger, size: button, onTap: () => context.push('/login')),
          SizedBox(width: gap),
          _Avatar(size: avatar),
          const Spacer(),
          _HeaderIcon(icon: Icons.settings_outlined, size: button, onTap: () => context.push('/settings')),
          SizedBox(width: gap),
          _HeaderIcon(icon: Icons.light_mode_outlined, size: button, color: AppColors.gold, onTap: () => context.push('/settings')),
          SizedBox(width: gap),
          Container(height: button, width: compact ? 42 : 54, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(15)), child: const Text('EN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          SizedBox(width: gap),
          if (!compact) Container(height: button, padding: const EdgeInsets.symmetric(horizontal: 11), alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.elevated, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)), child: Text('V${AppVersion.name}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
          if (!compact) const SizedBox(width: 10),
          Text('TRINEX', style: TextStyle(fontSize: compact ? 21 : 27, fontWeight: FontWeight.w900, letterSpacing: compact ? .4 : 1)),
          SizedBox(width: compact ? 8 : 12),
          Container(width: logo, height: logo, padding: compact ? const EdgeInsets.all(8) : const EdgeInsets.all(10), decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(compact ? 17 : 20), boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: .28), blurRadius: 22)]), child: Image.asset('assets/icons/trinex_icon.png')),
        ]);
      }),
    );
  }
}

class _MainNav extends StatelessWidget {
  const _MainNav({required this.selected});
  final int selected;
  static const items = [
    ('الملف', Icons.person_outline_rounded, '/student'),
    ('نظام', Icons.workspace_premium_outlined, '/system'),
    ('الجداول', Icons.calendar_month_outlined, '/schedule'),
    ('المواد', Icons.menu_book_outlined, '/materials'),
    ('أخبار', Icons.article_outlined, '/news'),
  ];
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 118,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: LayoutBuilder(builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / items.length;
        return Row(children: [for (var i = 0; i < items.length; i++) SizedBox(width: itemWidth, child: InkWell(onTap: () => context.go(items[i].$3), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(items[i].$2, size: 34, color: i == selected ? primary : AppColors.muted), const SizedBox(height: 8), Text(items[i].$1, style: TextStyle(fontSize: 17, fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500, color: i == selected ? primary : AppColors.muted))])))]);
      }),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.color, this.onTap, this.size = 48});
  final IconData icon; final Color? color; final VoidCallback? onTap; final double size;
  @override Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: SizedBox(width: size, height: size, child: Icon(icon, color: color ?? AppColors.text, size: size * .58))));
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.size = 50});
  final double size;
  @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.elevated, border: Border.all(color: AppColors.border, width: 2)), child: Center(child: Text('ع', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: size * .42, fontWeight: FontWeight.w900))));
}

class _EinoButton extends StatelessWidget {
  const _EinoButton({required this.animation});
  final Animation<double> animation;
  @override Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(animation: animation, builder: (context, _) {
      final glow = .18 + (.10 * (0.5 + 0.5 * (animation.value * 2 - 1).abs()));
      return InkWell(onTap: () => context.push('/eino?from=shell'), borderRadius: BorderRadius.circular(60), child: Container(width: 82, height: 82, padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.cyan, width: 4), boxShadow: [BoxShadow(color: primary.withValues(alpha: glow), blurRadius: 24)]), child: const EinoFace(size: 70, mood: EinoMood.happy)));
    });
  }
}
