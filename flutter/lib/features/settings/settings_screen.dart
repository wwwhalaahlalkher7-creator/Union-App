import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_version.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/update/update_service.dart';
import '../../core/theme/design_tokens.dart';
import 'settings_widgets.dart';

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
      final service = UpdateService(AppDependencies.instance.apiClient);
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
      final storage = AppDependencies.instance.authStorage;
      final token = await storage.accessToken;
      if (token?.isNotEmpty == true) {
        try {
          await AppDependencies.instance.apiClient.postJson('/api/v1/auth/logout');
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
                    SettingsHeader(title: l10n.t('settings'), subtitle: l10n.t('settingsSubtitle')),
                    const SizedBox(height: 16),
                    SettingsSection(
                      title: l10n.t('appearanceMode'),
                      icon: Icons.brightness_6_outlined,
                      child: SettingsModeSelector(
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
                    SettingsSection(
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
                                    SettingsAccentOption(
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
                    SettingsSection(
                      title: l10n.t('language'),
                      icon: Icons.translate_rounded,
                      child: SettingsLanguageSelector(
                        current: languageCode,
                        onChanged: (locale) {
                          if (locale != null) _changeLanguage(locale);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SettingsSection(
                      title: l10n.t('accountSettings'),
                      icon: Icons.manage_accounts_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.t('accountSettingsHelp'), style: TextStyle(color: context.colors.onSurfaceVariant)),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => context.push('/account-settings'),
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: Text(l10n.t('openAccountSettings')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SettingsSection(
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
                    SettingsLogoutTile(onTap: _confirmLogout, loading: _loggingOut),
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
