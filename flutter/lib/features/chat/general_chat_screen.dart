import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';

class GeneralChatScreen extends StatelessWidget {
  const GeneralChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('generalChat'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.forum_rounded, size: 58, color: scheme.primary),
              const SizedBox(height: 16),
              Text(l10n.t('comingSoon'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l10n.t('generalChatComingSoon'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}
