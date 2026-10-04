import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _openLegacyNewsDetail(BuildContext context) async {
    try {
      final items = await ContentRepository().news();
      if (!context.mounted) return;
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('noData'))),
        );
        return;
      }
      context.push('/news/detail', extra: items.first);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('connectionFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = <_MoreItem>[
      _MoreItem('media', Icons.campaign_outlined, '/media'),
      _MoreItem('notifications', Icons.notifications_none_rounded, '/notifications'),
      _MoreItem('progress', Icons.insights_rounded, '/progress'),
      _MoreItem('xpLevel', Icons.bolt_rounded, '/xp'),
      _MoreItem('badgesTitle', Icons.emoji_events_outlined, '/badges'),
      _MoreItem('achievements', Icons.military_tech_outlined, '/achievements'),
      _MoreItem('events', Icons.event_available_outlined, '/events'),
      _MoreItem('announcements', Icons.campaign_rounded, '/announcements'),
      _MoreItem('favorites', Icons.favorite_border_rounded, '/favorites'),
      _MoreItem('recent', Icons.history_rounded, '/recent'),
      _MoreItem('engineeringTools', Icons.construction_outlined, '/tools'),
      _MoreItem('market', Icons.storefront_outlined, '/market'),
      _MoreItem('settings', Icons.settings_outlined, '/settings'),
      _MoreItem('about', Icons.info_outline_rounded, '/about'),
      _MoreItem('legacyNews', Icons.article_outlined, '/news'),
      _MoreItem('legacyNewsDetail', Icons.article_rounded, '/news/detail', legacyDetail: true),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
      children: [
        Text(
          l10n.t('more'),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('allServices'),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
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
              onTap: item.legacyDetail
                  ? () => _openLegacyNewsDetail(context)
                  : () => context.push(item.route),
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
    );
  }
}

class _MoreItem {
  const _MoreItem(this.labelKey, this.icon, this.route, {this.legacyDetail = false});

  final String labelKey;
  final IconData icon;
  final String route;
  final bool legacyDetail;
}
