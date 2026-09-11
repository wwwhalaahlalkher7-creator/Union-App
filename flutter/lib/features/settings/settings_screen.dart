import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.locale,
    required this.onLocaleChanged,
    super.key,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.t('student')),
              subtitle: Text(l10n.t('studentOptional')),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push('/student'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(l10n.t('appearance')),
              subtitle: Text(_themeLabel(l10n, currentThemeMode)),
              onTap: () => _showThemePicker(context, l10n),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.t('language')),
              subtitle: Text(_languageLabel(l10n, locale)),
              onTap: () => _showLanguagePicker(context, l10n),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.t('about')),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push('/about'),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
        ThemeMode.light => l10n.t('light'),
        ThemeMode.dark => l10n.t('dark'),
        ThemeMode.system => l10n.t('system'),
      };

  String _languageLabel(AppLocalizations l10n, Locale? value) {
    final code = value?.languageCode ?? 'ar';
    return switch (code) {
      'en' => l10n.t('english'),
      'fr' => l10n.t('french'),
      _ => l10n.t('arabic'),
    };
  }

  Future<void> _showThemePicker(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(title: l10n.t('system'), selected: currentThemeMode == ThemeMode.system, onTap: () => Navigator.pop(context, ThemeMode.system)),
          _Option(title: l10n.t('light'), selected: currentThemeMode == ThemeMode.light, onTap: () => Navigator.pop(context, ThemeMode.light)),
          _Option(title: l10n.t('dark'), selected: currentThemeMode == ThemeMode.dark, onTap: () => Navigator.pop(context, ThemeMode.dark)),
        ],
      ),
    );
    if (selected != null) onThemeModeChanged(selected);
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final selected = await showModalBottomSheet<Locale?>(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(title: l10n.t('arabic'), selected: locale?.languageCode == 'ar' || locale == null, onTap: () => Navigator.pop(context, const Locale('ar'))),
          _Option(title: l10n.t('english'), selected: locale?.languageCode == 'en', onTap: () => Navigator.pop(context, const Locale('en'))),
          _Option(title: l10n.t('french'), selected: locale?.languageCode == 'fr', onTap: () => Navigator.pop(context, const Locale('fr'))),
          _Option(title: 'تلقائي / Auto', selected: locale == null, onTap: () => Navigator.pop(context, null)),
        ],
      ),
    );
    // null also represents automatic mode, so the explicit Arabic selection
    // above is distinguishable by the current locale after rebuild.
    if (selected != null) {
      onLocaleChanged(selected);
    } else if (locale != null) {
      onLocaleChanged(null);
    }
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: onTap,
      );
}
