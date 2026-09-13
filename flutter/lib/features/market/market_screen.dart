import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/responsive_content.dart';

/// The marketplace is intentionally data-empty until its Dashboard/API contract
/// is available. V2 never presents fake listings as if they were real.
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('market')),
        actions: [IconButton(onPressed: null, tooltip: l10n.t('favorites'), icon: const Icon(Icons.bookmark_border_rounded))],
      ),
      body: ResponsiveContent(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              enabled: false,
              decoration: InputDecoration(hintText: l10n.t('marketSearch'), prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .11), shape: BoxShape.circle), child: Icon(Icons.storefront_rounded, size: 34, color: cs.primary)),
                  const SizedBox(height: 16),
                  Text(l10n.t('marketComingSoon'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(l10n.t('marketComingSoonSubtitle'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [Icon(Icons.verified_user_outlined, color: cs.primary), const SizedBox(width: 10), Expanded(child: Text(l10n.t('marketTrustNote'), style: Theme.of(context).textTheme.bodySmall))]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(l10n.t('marketPlanTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final item in [
              (Icons.dashboard_customize_outlined, l10n.t('marketPlanDashboard')),
              (Icons.sync_rounded, l10n.t('marketPlanApi')),
              (Icons.verified_outlined, l10n.t('marketPlanStudent')),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(leading: Icon(item.$1, color: cs.primary), title: Text(item.$2)),
              ),
          ],
        ),
      ),
    );
  }
}
