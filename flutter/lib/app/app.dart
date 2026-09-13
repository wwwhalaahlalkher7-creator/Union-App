import 'dart:async';
import 'package:flutter/material.dart';

import '../core/app_version.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/storage/app_preferences.dart';
import '../core/update/update_service.dart';
import '../core/update/update_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'router.dart';
import '../features/splash/trinex_splash_screen.dart';

class TrinexApp extends StatefulWidget {
  const TrinexApp({super.key});

  @override
  State<TrinexApp> createState() => _TrinexAppState();
}

/// Backwards-compatible name for existing tests and integrations.
typedef LeoAssociationApp = TrinexApp;

class _TrinexAppState extends State<TrinexApp> {
  final AppPreferences _preferences = AppPreferences();
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkForUpdate();
    _splashTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    if (!mounted) return;
    setState(() {
      _themeMode = _preferences.themeMode;
      _locale = _preferences.locale;
    });
  }


  Future<void> _checkForUpdate() async {
    final info = await const UpdateService().check();
    if (!mounted || info == null) return;
    const service = UpdateService();
    if (!service.isForceRequired(info) && !service.isOptional(info)) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _showUpdateDialog(info, force: service.isForceRequired(info));
  }

  Future<void> _showUpdateDialog(UpdateInfo info, {required bool force}) async {
    final title = force ? 'تحديث مطلوب' : 'تحديث جديد متاح';
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
              const Text('الإصدار المثبت: ${AppVersion.full}'),
              const SizedBox(height: 4),
              Text('الإصدار المتاح: ${info.currentVersion}'),
              if (force) ...[
                const SizedBox(height: 12),
                const Text('يجب تحديث التطبيق للمتابعة لأن هذه النسخة لم تعد مدعومة.'),
              ],
              if ((info.releaseNotes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(info.releaseNotes!),
              ],
            ],
          ),
        ),
        actions: [
          if (!force) TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لاحقًا')),
          FilledButton.icon(
            onPressed: info.updateUrl == null || info.updateUrl!.trim().isEmpty ? null : () async {
              final uri = Uri.tryParse(info.updateUrl!);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.system_update_rounded),
            label: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _splashTimer = null;
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppLocalizations.supportedLocales.first.languageCode == 'ar'
          ? 'TRINEX'
          : 'TRINEX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: buildRouter(
        onThemeModeChanged: setThemeMode,
        onLocaleChanged: setLocale,
        themeMode: _themeMode,
        locale: _locale,
      ),
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child ?? const SizedBox.shrink(),
          IgnorePointer(
            ignoring: !_showSplash,
            child: AnimatedOpacity(
              opacity: _showSplash ? 1 : 0,
              duration: const Duration(milliseconds: 360),
              child: const TrinexSplashScreen(),
            ),
          ),
        ],
      ),
    );
  }
}
