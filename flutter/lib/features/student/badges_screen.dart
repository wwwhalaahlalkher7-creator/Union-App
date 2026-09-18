import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/badge_item.dart';
import '../../data/repositories/badges_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';
import '../../shared/widgets/list_skeleton.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});
  @override State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  ApiClient? _client;
  BadgeSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      _client ??= await AuthenticatedClient.create();
      final snapshot = await BadgesRepository(_client!).getBadges();
      if (mounted) setState(() { _snapshot = snapshot; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : AppLocalizations.of(context).t('badgesLoadError'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _client?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = _snapshot;
    Widget body;
    if (_loading && snapshot == null) {
      body = const ListSkeleton(count: 6);
    } else if (_error != null && snapshot == null) {
      body = _BadgeError(message: _error!, retry: _load);
    } else {
      final ratio = snapshot!.totalCount == 0 ? 0.0 : (snapshot.earnedCount / snapshot.totalCount).clamp(0.0, 1.0).toDouble();
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(14.72, 9.2, 14.72, 33.12),
          children: [
            AppCard(
              padding: const EdgeInsets.all(18.4),
              child: Column(children: [
                Container(width: 68, height: 68, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.emoji_events_rounded, size: 36, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 12),
                Text(l10n.t('achievementsTitle'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(l10n.t('badgesEarned', {'earned': '${snapshot.earnedCount}', 'total': '${snapshot.totalCount}'})),
                const SizedBox(height: 15),
                LinearProgressIndicator(value: ratio, minHeight: 8, borderRadius: BorderRadius.circular(7.2)),
              ]),
            ),
            const SizedBox(height: 22),
            AppSection(
              title: l10n.t('badgeCollection'),
              child: LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.badges.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .92),
                  itemBuilder: (context, index) => _BadgeCard(badge: snapshot.badges[index]),
                );
              }),
            ),
          ],
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: Text(l10n.t('badgesTitle')), actions: [IconButton(tooltip: l10n.t('refresh'), onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]), body: body);
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});
  final BadgeItem badge;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    return AppCard(
      padding: const EdgeInsets.all(11.04),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: badge.earned ? cs.primaryContainer : cs.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(badge.earned ? Icons.emoji_events_rounded : Icons.lock_outline_rounded, color: badge.earned ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
        const SizedBox(height: 9),
        Text(badge.localizedName(languageCode), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: badge.earned ? cs.onSurface : cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(badge.localizedDescription(languageCode).isEmpty ? _rule(badge) : badge.localizedDescription(languageCode), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        if (badge.earned) ...[const SizedBox(height: 6), Icon(Icons.check_circle_rounded, size: 18, color: cs.primary)],
      ]),
    );
  }
  String _rule(BadgeItem badge) => '${badge.ruleType}: ${badge.ruleValue}';
}

class _BadgeError extends StatelessWidget {
  const _BadgeError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(25.76), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.emoji_events_outlined, size: 58, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(AppLocalizations.of(context).t('retry')))])));
}
