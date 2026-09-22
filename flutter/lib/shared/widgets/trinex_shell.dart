import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_version.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/eino/eino_face.dart';

class TrinexShell extends StatefulWidget {
  const TrinexShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  State<TrinexShell> createState() => _TrinexShellState();
}

class _TrinexShellState extends State<TrinexShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

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
    if (widget.location.startsWith('/news') ||
        widget.location.startsWith('/media')) {
      return 4;
    }
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
            Expanded(
              child: Stack(
                children: [
                  widget.child,
                  PositionedDirectional(
                    end: 16,
                    bottom: 18,
                    child: _EinoButton(animation: _pulse),
                  ),
                ],
              ),
            ),
            _MainNav(selected: index),
            const SizedBox(height: 4),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 600;
          final button = compact ? 44.0 : 48.0;
          final avatar = compact ? 36.0 : 40.0;
          final logo = compact ? 40.0 : 44.0;
          final primary = context.colors.primary;

          return Row(
            children: [
              _HeaderIcon(
                icon: Icons.storefront_outlined,
                size: button,
                tooltip: l10n.t('market'),
                onTap: () => context.push('/market'),
              ),
              const SizedBox(width: 4),
              _Avatar(
                size: avatar,
                onTap: () => context.go('/student'),
              ),
              const Spacer(),
              if (!compact)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    border: Border.all(color: context.colors.outlineVariant),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: Text(
                    'V${AppVersion.name}',
                    style: TextStyle(
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (!compact) const SizedBox(width: 8),
              Text(
                'TRINEX',
                style: TextStyle(
                  fontSize: compact ? 17 : 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: logo,
                height: logo,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Image.asset('assets/icons/trinex_icon.png'),
              ),
              const SizedBox(width: 4),
              _HeaderIcon(
                icon: Icons.settings_outlined,
                size: button,
                tooltip: l10n.t('settings'),
                onTap: () => context.push('/settings'),
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
    ('الطالب', Icons.person_outline_rounded, '/student'),
    ('النظام', Icons.workspace_premium_outlined, '/system'),
    ('الجداول', Icons.calendar_month_outlined, '/schedule'),
    ('المواد', Icons.menu_book_outlined, '/materials'),
    ('الإعلام', Icons.campaign_outlined, '/media'),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selected.clamp(0, items.length - 1),
      height: 68,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: context.colors.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) => context.go(items[i].$3),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.$2),
            selectedIcon: Icon(item.$2),
            label: item.$1,
          ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: context.colors.onSurface,
              size: 23,
            ),
          ),
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
    return Tooltip(
      message: l10n.t('profile'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.surfaceContainerHigh,
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Icon(
            Icons.account_circle_rounded,
            color: context.colors.primary,
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
    final primary = context.colors.primary;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final glow =
            .12 + (.10 * (0.5 + 0.5 * (animation.value * 2 - 1).abs()));
        return Semantics(
          button: true,
          label: 'Eino',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/eino?from=shell'),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.surface,
                  border: Border.all(
                    color: context.colors.primary,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: glow),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const EinoFace(
                  size: 52,
                  mood: EinoMood.happy,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
