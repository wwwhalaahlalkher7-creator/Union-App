import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/badge_item.dart';
import '../../data/repositories/badges_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  ApiClient? _client;
  BadgeSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _client ??= await AuthenticatedClient.create();
      final snapshot = await BadgesRepository(_client!).getBadges();
      if (mounted) setState(() { _snapshot = snapshot; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذر تحميل الشارات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    Widget body;

    if (_loading && snapshot == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && snapshot == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.emoji_events_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إنجازاتك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${snapshot!.earnedCount} من ${snapshot.totalCount} شارة مكتسبة'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppSection(
              title: 'مجموعة الشارات',
              child: Column(
                children: [
                  for (final badge in snapshot.badges)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: badge.earned ? Theme.of(context).colorScheme.primaryContainer : null,
                              child: Icon(
                                badge.earned ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                                color: badge.earned ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    badge.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: badge.earned ? null : Theme.of(context).disabledColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    badge.description.isEmpty ? _rule(badge) : badge.description,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (badge.earned) const Icon(Icons.check_circle_rounded),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الشارات'),
        actions: [IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: body,
    );
  }

  String _rule(BadgeItem badge) => '${badge.ruleType}: ${badge.ruleValue}';
}
