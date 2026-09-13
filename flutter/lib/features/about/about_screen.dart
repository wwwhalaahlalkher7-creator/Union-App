import 'package:flutter/material.dart';
import '../../core/app_version.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../core/update/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    const service = UpdateService();
    final info = await service.check();
    if (!context.mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('updateCheckFailed'))));
      return;
    }
    final newer = service.isOptional(info) || service.isForceRequired(info);
    if (!newer) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('upToDate'))));
      return;
    }
    final url = info.updateUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('updateLinkMissing', {'version': info.currentVersion}))));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (service.isForceRequired(info) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('forceUpdateShort'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('about'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 42, child: Icon(Icons.groups_outlined, size: 42)),
              const SizedBox(height: 18),
              Text(
                l10n.t('appName'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              AppCard(child: Column(
                children: [
                  Text(l10n.t('versionLabel', {'version': AppVersion.full}), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _checkUpdate(context),
                    icon: const Icon(Icons.system_update_rounded),
                    label: Text(l10n.t('checkUpdates')),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
