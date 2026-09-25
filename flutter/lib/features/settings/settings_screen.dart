import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_version.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/update/update_service.dart';
import '../../shared/widgets/app_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.accentColorId,
    this.onAccentColorChanged,
    super.key,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final String? accentColorId;
  final ValueChanged<String>? onAccentColorChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdate = false;
  bool _loggingOut = false;
  bool _changingLanguage = false;
  late String _selectedAccentId;
  late String _selectedLanguageCode;
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    _selectedAccentId = AppAccentColor.fromId(widget.accentColorId).id;
    _selectedLanguageCode = widget.locale?.languageCode ?? 'ar';
    _selectedThemeMode = widget.currentThemeMode;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent updates can rebuild MaterialApp.router while the same route
    // remains mounted. Keep the local selection in sync without losing the
    // immediate visual feedback from a tap.
    if (!_changingLanguage && widget.locale?.languageCode != oldWidget.locale?.languageCode) {
      _selectedLanguageCode = widget.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
    }
    if (widget.accentColorId != oldWidget.accentColorId) {
      _selectedAccentId = AppAccentColor.fromId(widget.accentColorId).id;
    }
    if (widget.currentThemeMode != oldWidget.currentThemeMode) {
      _selectedThemeMode = widget.currentThemeMode;
    }
  }

  Future<void> _changeLanguage(Locale locale) async {
    if (_changingLanguage || _selectedLanguageCode == locale.languageCode) return;
    setState(() {
      _selectedLanguageCode = locale.languageCode;
      _changingLanguage = true;
    });

    // Let the user see a deliberate transition before Flutter flips the
    // entire text direction and rebuilds the localized tree.
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    widget.onLocaleChanged(locale);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) setState(() => _changingLanguage = false);
  }

  void _changeTheme(ThemeMode mode) {
    if (_selectedThemeMode == mode) return;
    setState(() => _selectedThemeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  void _changeAccent(String colorId) {
    if (_selectedAccentId == colorId) return;
    setState(() => _selectedAccentId = colorId);
    widget.onAccentColorChanged?.call(colorId);
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      const service = UpdateService();
      final info = await service.check();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = info == null
          ? l10n.t('updateCheckFailed')
          : service.isOptional(info)
              ? '${l10n.t('updateAvailable')}: ${info.currentVersion}'
              : l10n.t('upToDate');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      final storage = await AuthStorage.create();
      final token = await storage.accessToken;
      if (token?.isNotEmpty == true) {
        try {
          final client = await AuthenticatedClient.create();
          await client.postJson('/api/v1/auth/logout');
          client.dispose();
        } catch (_) {}
      }
      await storage.clear();
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('logout')),
        content: Text(l10n.t('logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.t('logout')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedAccentId = _selectedAccentId;
    final languageCode = _selectedLanguageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(title: l10n.t('settings'), subtitle: l10n.t('settingsSubtitle')),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: l10n.t('appearanceMode'),
                      icon: Icons.brightness_6_outlined,
                      child: _ModeSelector(
                        current: _selectedThemeMode,
                        onChanged: _changeTheme,
                        labels: {
                          ThemeMode.system: l10n.t('system'),
                          ThemeMode.light: l10n.t('light'),
                          ThemeMode.dark: l10n.t('dark'),
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: l10n.t('accentColor'),
                      icon: Icons.palette_outlined,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Compact color-picker: circles only, with accessible
                          // semantic labels and a tooltip on long-press.
                          const itemSize = 52.0;
                          const gap = 10.0;
                          final columns = ((constraints.maxWidth + gap) / (itemSize + gap)).floor().clamp(4, 8).toInt();
                          final totalWidth = columns * itemSize + (columns - 1) * gap;
                          return Center(
                            child: SizedBox(
                              width: totalWidth,
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final color in AppAccentColor.presets)
                                    _AccentOption(
                                      color: color,
                                      selected: selectedAccentId == color.id,
                                      languageCode: languageCode,
                                      onTap: widget.onAccentColorChanged == null ? null : () => _changeAccent(color.id),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: l10n.t('language'),
                      icon: Icons.translate_rounded,
                      child: _LanguageSelector(
                        current: languageCode,
                        onChanged: (locale) {
                          if (locale != null) _changeLanguage(locale);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: l10n.t('appInfo'),
                      icon: Icons.info_outline_rounded,
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.apps_rounded, color: context.colors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TRINEX Engine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text(
                                  'v${AppVersion.name}  •  Build #${AppVersion.build}',
                                  style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _checkingUpdate ? null : _checkForUpdate,
                            icon: _checkingUpdate
                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh_rounded, size: 17),
                            label: Text(_checkingUpdate ? l10n.t('checking') : l10n.t('checkUpdates')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LogoutTile(onTap: _confirmLogout, loading: _loggingOut),
                  ],
                ),
              ),
            ),
          ],
        ),
            if (_changingLanguage)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: .30),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.colors.primary.withValues(alpha: .35)),
                        boxShadow: [BoxShadow(color: context.colors.primary.withValues(alpha: .18), blurRadius: 24)],
                      ),
                      child: const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.icon, required this.child});
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

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.current, required this.onChanged, required this.labels});
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
                child: _ChoiceOption(
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

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    const languages = [
      ('ar', 'العربية', 'RTL', Icons.translate_rounded),
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
                child: _LanguageOption(
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

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({required this.label, required this.icon, required this.selected, required this.onTap});
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
                if (selected) const PositionedDirectional(top: 6, end: 6, child: _SelectedMark()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentOption extends StatelessWidget {
  const _AccentOption({
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
    final primary = color.primary;
    final label = color.localizedName(languageCode);

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      hint: selected ? 'محدد' : 'اضغط لاختيار اللون',
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
              child: AnimatedSwitcher(
                duration: DesignTokens.fast,
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('selected'),
                        size: 24,
                        color: Colors.white,
                      )
                    : const SizedBox(key: ValueKey('empty')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.name, required this.direction, required this.icon, required this.selected, required this.onTap});
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
                if (selected) const PositionedDirectional(top: 6, end: 6, child: _SelectedMark()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark();

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

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap, required this.loading});
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
