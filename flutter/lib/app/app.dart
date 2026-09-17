import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_version.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/storage/app_preferences.dart';
import '../core/update/update_service.dart';
import '../core/update/update_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'router.dart';

class TrinexApp extends StatefulWidget {
  const TrinexApp({
    super.key,
    this.enableStartupUpdateCheck = false,
    this.startupFutureOverride,
    this.initialLocationOverride,
  });

  final bool enableStartupUpdateCheck;
  final Future<void>? startupFutureOverride;
  final String? initialLocationOverride;

  @override
  State<TrinexApp> createState() => _TrinexAppState();
}

/// Backwards-compatible name for existing tests and integrations.
typedef LeoAssociationApp = TrinexApp;

class _TrinexAppState extends State<TrinexApp> {
  final AppPreferences _preferences = AppPreferences();
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  String _accentColorId = 'orange';
  late final Future<void> _preferencesFuture =
      widget.startupFutureOverride ?? _loadPreferences();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      startupFuture: _preferencesFuture,
      onThemeModeChanged: setThemeMode,
      onLocaleChanged: setLocale,
      onAccentColorChanged: setAccentColor,
      accentColorId: () => _accentColorId,
      themeMode: () => _themeMode,
      locale: () => _locale,
      initialLocation: widget.initialLocationOverride ?? '/splash',
    );
    if (widget.enableStartupUpdateCheck) _checkForUpdate();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    if (!mounted) return;
    setState(() {
      _themeMode = _preferences.themeMode;
      _locale = _preferences.locale;
      _accentColorId = _preferences.accentColorId;
    });
  }


  Future<void> _checkForUpdate() async {
    await _preferencesFuture;
    final info = await const UpdateService().check();
    if (!mounted || info == null) return;
    const service = UpdateService();
    if (!service.isForceRequired(info) && !service.isOptional(info)) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _showUpdateDialog(info, force: service.isForceRequired(info));
  }

  Future<void> _showUpdateDialog(UpdateInfo info, {required bool force}) async {
    final l10n = AppLocalizations.of(context);
    final title = force ? l10n.t('updateRequired') : l10n.t('updateAvailable');
    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.t('installedVersion', {'version': AppVersion.full})),
              const SizedBox(height: 4),
              Text(l10n.t('availableVersion', {'version': info.currentVersion})),
              if (force) ...[
                const SizedBox(height: 12),
                Text(l10n.t('forceUpdateMessage')),
              ],
              if ((info.releaseNotes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(info.releaseNotes!),
              ],
            ],
          ),
        ),
        actions: [
          if (!force) TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.t('later'))),
          FilledButton.icon(
            onPressed: info.updateUrl == null || info.updateUrl!.trim().isEmpty ? null : () async {
              final uri = Uri.tryParse(info.updateUrl!);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.system_update_rounded),
            label: Text(l10n.t('updateNow')),
          ),
        ],
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _preferences.setThemeMode(mode);
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  Future<void> setLocale(Locale? locale) async {
    await _preferences.setLocale(locale);
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  Future<void> setAccentColor(String colorId) async {
    await _preferences.setAccentColorId(colorId);
    if (!mounted) return;
    setState(() => _accentColorId = colorId);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentColor.fromId(_accentColorId);
    return MaterialApp.router(
      title: 'TRINEX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: accent),
      darkTheme: AppTheme.dark(accent: accent),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
