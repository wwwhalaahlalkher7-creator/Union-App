import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/app_card.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 17, 18, 17),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.primary.withValues(alpha: .22)),
            ),
            child: Icon(Icons.tune_rounded, color: context.colors.primary, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: context.colors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class SettingsModeSelector extends StatelessWidget {
  const SettingsModeSelector({required this.current, required this.onChanged, required this.labels});
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  final Map<ThemeMode, String> labels;

  @override
  Widget build(BuildContext context) {
    final items = [
      (ThemeMode.system, Icons.brightness_auto_outlined),
      (ThemeMode.light, Icons.light_mode_outlined),
      (ThemeMode.dark, Icons.dark_mode_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              SizedBox(
                width: width,
                child: SettingsChoiceOption(
                  label: labels[items[i].$1]!,
                  icon: items[i].$2,
                  selected: current == items[i].$1,
                  onTap: () => onChanged(items[i].$1),
                ),
              ),
              if (i != items.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class SettingsLanguageSelector extends StatelessWidget {
  const SettingsLanguageSelector({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languages = [
      ('ar', l10n.t('arabic'), 'RTL', Icons.translate_rounded),
      ('en', 'English', 'LTR', Icons.language_rounded),
      ('fr', 'Français', 'LTR', Icons.language_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Row(
          children: [
            for (var i = 0; i < languages.length; i++) ...[
              SizedBox(
                width: width,
                child: SettingsLanguageOption(
                  name: languages[i].$2,
                  direction: languages[i].$3,
                  icon: languages[i].$4,
                  selected: current == languages[i].$1,
                  onTap: () => onChanged(Locale(languages[i].$1)),
                ),
              ),
              if (i != languages.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class SettingsChoiceOption extends StatelessWidget {
  const SettingsChoiceOption({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: DesignTokens.normal,
            curve: Curves.easeOut,
            height: 64,
            decoration: BoxDecoration(
              color: selected ? primary.withValues(alpha: .12) : context.colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? primary : context.colors.outlineVariant, width: selected ? 1.6 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: primary.withValues(alpha: .20), blurRadius: 12, spreadRadius: 0)]
                  : const [],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: selected ? primary : context.colors.onSurfaceVariant),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: selected ? primary : context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (selected) const PositionedDirectional(top: 6, end: 6, child: SettingsSelectedMark()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsAccentOption extends StatelessWidget {
  const SettingsAccentOption({
    required this.color,
    required this.selected,
    required this.languageCode,
    required this.onTap,
  });

  final AppAccentColor color;
  final bool selected;
  final String languageCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? color.primaryDark : color.primary;
    final label = color.localizedName(languageCode);
    final checkColor = color.isThemeAdaptive
        ? (isDark ? Colors.black : Colors.white)
        : Colors.white;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      hint: selected ? l10n.t('selected') : l10n.t('selectColor'),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 450),
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            child: AnimatedContainer(
              duration: DesignTokens.normal,
              curve: Curves.easeOut,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary,
                border: Border.all(
                  color: selected ? context.colors.onSurface : Colors.transparent,
                  width: selected ? 3 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: selected ? .38 : .20),
                    blurRadius: selected ? 12 : 6,
                    spreadRadius: selected ? 1 : 0,
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (color.isThemeAdaptive)
                    const ClipOval(
                      child: CustomPaint(
                        painter: BlackWhiteAccentPainter(),
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: DesignTokens.fast,
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('selected'),
                            size: 24,
                            color: checkColor,
                          )
                        : const SizedBox(key: ValueKey('empty')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlackWhiteAccentPainter extends CustomPainter {
  const BlackWhiteAccentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = Colors.black;

    canvas.drawRect(rect, white);

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, black);

    final line = Paint()
      ..color = Colors.transparent
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant BlackWhiteAccentPainter oldDelegate) => false;
}

class SettingsLanguageOption extends StatelessWidget {
  const SettingsLanguageOption({required this.name, required this.direction, required this.icon, required this.selected, required this.onTap});
  final String name;
  final String direction;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      selected: selected,
      button: true,
      label: name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: DesignTokens.normal,
            curve: Curves.easeOut,
            height: 64,
            decoration: BoxDecoration(
              color: selected ? primary.withValues(alpha: .12) : context.colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? primary : context.colors.outlineVariant, width: selected ? 1.6 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: primary.withValues(alpha: .20), blurRadius: 12)]
                  : const [],
            ),
            child: Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: selected ? primary : context.colors.onSurfaceVariant),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: selected ? primary : context.colors.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(direction, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: context.colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) const PositionedDirectional(top: 6, end: 6, child: SettingsSelectedMark()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSelectedMark extends StatelessWidget {
  const SettingsSelectedMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
    );
  }
}

class SettingsLogoutTile extends StatelessWidget {
  const SettingsLogoutTile({required this.onTap, required this.loading});
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.t('logout'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800))),
              if (loading)
                const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}
