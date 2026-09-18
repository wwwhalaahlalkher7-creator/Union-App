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
    final selected = AppAccentColor.presets
        .firstWhere(
          (color) => color.primary == context.colors.primary,
          orElse: () => AppAccentColor.fromId(widget.accentColorId),
        )
        .id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      title: l10n.t('settings'),
                      subtitle: l10n.t('settingsSubtitle'),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: l10n.t('appearanceMode'),
                      icon: Icons.brightness_6_outlined,
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeCard(
                              l10n.t('system'),
                              Icons.brightness_auto_outlined,
                              widget.currentThemeMode == ThemeMode.system,
                              () => widget.onThemeModeChanged(ThemeMode.system),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _ModeCard(
                              l10n.t('light'),
                              Icons.light_mode_outlined,
                              widget.currentThemeMode == ThemeMode.light,
                              () => widget.onThemeModeChanged(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _ModeCard(
                              l10n.t('dark'),
                              Icons.dark_mode_outlined,
                              widget.currentThemeMode == ThemeMode.dark,
                              () => widget.onThemeModeChanged(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Section(
                      title: l10n.t('accentColor'),
                      icon: Icons.palette_outlined,
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final color in AppAccentColor.presets)
                            _AccentCard(
                              color: color,
                              selected: selected == color.id,
                              arabic: widget.locale?.languageCode == 'ar',
                              onTap: widget.onAccentColorChanged == null
                                  ? null
                                  : () => widget.onAccentColorChanged!(color.id),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Section(
                      title: l10n.t('language'),
                      icon: Icons.translate_rounded,
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _LanguageCard('العربية (RTL)', const Locale('ar'), widget.locale?.languageCode == 'ar', widget.onLocaleChanged),
                          _LanguageCard('English (LTR)', const Locale('en'), widget.locale?.languageCode == 'en', widget.onLocaleChanged),
                          _LanguageCard('Français (LTR)', const Locale('fr'), widget.locale?.languageCode == 'fr', widget.onLocaleChanged),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Section(
                      title: l10n.t('appInfo'),
                      icon: Icons.info_outline_rounded,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TRINEX Engine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text('v${AppVersion.name}  •  Build #${AppVersion.build}', style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 9.5)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _checkingUpdate ? null : _checkForUpdate,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            ),
                            icon: _checkingUpdate
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(_checkingUpdate ? l10n.t('checking') : l10n.t('checkUpdates'), style: const TextStyle(fontSize: 9.5)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LogoutTile(onTap: _confirmLogout, loading: _loggingOut),
                  ],
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
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.colors.primary),
              const SizedBox(width: 7),
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(this.label, this.icon, this.selected, this.onTap);
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: .10) : context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? context.colors.primary : context.colors.outline, width: selected ? 1.4 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? context.colors.primary : context.colors.onSurfaceVariant),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: selected ? context.colors.primary : context.colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _AccentCard extends StatelessWidget {
  const _AccentCard({required this.color, required this.selected, required this.arabic, required this.onTap});
  final AppAccentColor color;
  final bool selected;
  final bool arabic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = arabic ? color.nameAr : color.nameEn;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 78,
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? color.primary : context.colors.outline, width: selected ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: color.primary, shape: BoxShape.circle)),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: context.colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard(this.label, this.locale, this.selected, this.onChanged);
  final String label;
  final Locale locale;
  final bool selected;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(locale),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: .10) : context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? context.colors.primary : context.colors.outline, width: selected ? 1.4 : 1),
        ),
        child: Text(label, style: TextStyle(color: selected ? context.colors.primary : context.colors.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 9.5)),
      ),
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
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withValues(alpha: .30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(l10n.t('logout'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
            if (loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
