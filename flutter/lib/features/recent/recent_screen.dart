import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';

class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('recent'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 64),
              const SizedBox(height: 16),
              Text(l10n.t('noData'), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
