import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const services = <_MoreItem>[
      _MoreItem('notifications', Icons.notifications_none_rounded, '/notifications'),
      _MoreItem('progress', Icons.insights_rounded, '/progress'),
      _MoreItem('xpLevel', Icons.bolt_rounded, '/xp'),
      _MoreItem('achievements', Icons.emoji_events_outlined, '/badges'),
      _MoreItem('activities', Icons.event_available_outlined, '/activities'),
      _MoreItem('announcements', Icons.campaign_outlined, '/announcements'),
      _MoreItem('favorites', Icons.favorite_border_rounded, '/favorites'),
      _MoreItem('recent', Icons.history_rounded, '/recent'),
      _MoreItem('engineeringTools', Icons.construction_outlined, '/tools'),
      _MoreItem('market', Icons.storefront_outlined, '/market'),
      _MoreItem('settings', Icons.settings_outlined, '/settings'),
      _MoreItem('about', Icons.info_outline_rounded, '/about'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('more'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        children: [
          Text(l10n.t('allServices'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.45,
            ),
            itemBuilder: (context, index) {
              final item = services[index];
              return AppCard(
                onTap: () => context.push(item.route),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(item.icon, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.t(item.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.labelKey, this.icon, this.route);
  final String labelKey;
  final IconData icon;
  final String route;
}
