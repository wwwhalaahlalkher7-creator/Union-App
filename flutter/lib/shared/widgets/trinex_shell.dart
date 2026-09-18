import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_version.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/eino/eino_face.dart';

class TrinexShell extends StatefulWidget {
  const TrinexShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  @override
  State<TrinexShell> createState() => _TrinexShellState();
}

class _TrinexShellState extends State<TrinexShell> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int get index {
    if (widget.location.startsWith('/student')) return 0;
    if (widget.location.startsWith('/system')) return 1;
    if (widget.location.startsWith('/schedule')) return 2;
    if (widget.location.startsWith('/materials')) return 3;
    if (widget.location.startsWith('/news') || widget.location.startsWith('/media')) return 4;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _TopHeader(),
              _MainNav(selected: index),
              Expanded(
                child: Stack(
                  children: [
                    widget.child,
                    PositionedDirectional(
                      end: 14,
                      bottom: 14,
                      child: _EinoButton(animation: _pulse),
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

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 9.2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: context.colors.outline)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 600;
          final button = compact ? 32.0 : 36.0;
          final avatar = compact ? 32.0 : 36.0;
          final logo = compact ? 38.0 : 42.0;
          final gap = compact ? 4.0 : 6.0;
          final primary = Theme.of(context).colorScheme.primary;

          return Row(
            children: [
              _HeaderIcon(
                icon: Icons.storefront_outlined,
                size: button,
                onTap: () => context.push('/market'),
              ),
              SizedBox(width: gap),
              _Avatar(size: avatar, onTap: () => context.go('/student')),
              const Spacer(),
              _HeaderIcon(
                icon: Icons.settings_outlined,
                size: button,
                onTap: () => context.push('/settings'),
              ),
              SizedBox(width: gap),
              if (!compact) ...[
                Container(
                  height: button,
                  padding: const EdgeInsets.symmetric(horizontal: 6.44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    border: Border.all(color: context.colors.outline),
                    borderRadius: BorderRadius.circular(9.9),
                  ),
                  child: Text(
                    'V${AppVersion.name}',
                    style: TextStyle(color: context.colors.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'TRINEX',
                style: TextStyle(fontSize: compact ? 17 : 20, fontWeight: FontWeight.w900, letterSpacing: .3),
              ),
              SizedBox(width: compact ? 5 : 7),
              Container(
                width: logo,
                height: logo,
                padding: const EdgeInsets.all(6.44),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12.6),
                  boxShadow: [BoxShadow(color: primary.withValues(alpha: .25), blurRadius: 18)],
                ),
                child: Image.asset('assets/icons/trinex_icon.png'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MainNav extends StatelessWidget {
  const _MainNav({required this.selected});
  final int selected;

  static const items = [
    ('السوق', Icons.storefront_outlined, '/market'),
    ('نظام', Icons.workspace_premium_outlined, '/system'),
    ('الجداول', Icons.calendar_month_outlined, '/schedule'),
    ('المواد', Icons.menu_book_outlined, '/materials'),
    ('الإعلام', Icons.campaign_outlined, '/media'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 64,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.outline))),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => context.go(items[i].$3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i].$2, size: 20, color: i == selected ? primary : context.colors.onSurfaceVariant),
                    const SizedBox(height: 5),
                    Text(
                      items[i].$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500,
                        color: i == selected ? primary : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.onTap, this.size = 48});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.6),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: context.colors.onSurface, size: size * .55),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.size = 50, this.onTap});
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colors.surfaceContainerHigh,
          border: Border.all(color: context.colors.outline, width: 2),
        ),
        child: Center(
          child: Icon(
            Icons.account_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: size * .62,
          ),
        ),
      ),
    );
  }
}

class _EinoButton extends StatelessWidget {
  const _EinoButton({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final glow = .18 + (.10 * (0.5 + 0.5 * (animation.value * 2 - 1).abs()));
        return InkWell(
          onTap: () => context.push('/eino?from=shell'),
          borderRadius: BorderRadius.circular(54),
          child: Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(3.68),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.surface,
              border: Border.all(color: context.colors.secondary, width: 3),
              boxShadow: [BoxShadow(color: primary.withValues(alpha: glow), blurRadius: 20)],
            ),
            child: const EinoFace(size: 52, mood: EinoMood.happy),
          ),
        );
      },
    );
  }
}
