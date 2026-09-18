import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/list_skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  ApiClient? _client;
  NotificationsRepository? _repository;
  Future<List<NotificationItem>>? _future;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final client = await AuthenticatedClient.create();
      if (!mounted) {
        client.dispose();
        return;
      }
      _client = client;
      _repository = NotificationsRepository(client);
      setState(() => _future = _repository!.list());
    } catch (_) {
      if (mounted) setState(() => _future = Future.error(Exception()));
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final repo = _repository;
    if (repo == null) return;
    final future = repo.list();
    setState(() => _future = future);
    await future;
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    final repo = _repository;
    if (repo == null) return;
    try {
      await repo.markRead([item.id]);
      if (mounted) setState(() => _future = repo.list());
    } catch (_) {
      // Keep the notification visible; a later refresh can retry the operation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('notifications')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: _repository == null ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _future == null) {
            return const ListSkeleton(count: 5);
          }
          if (snapshot.hasError) {
            return _StateView(
              icon: Icons.cloud_off_rounded,
              title: l10n.t('connectionFailed'),
              action: l10n.t('retry'),
              onAction: _reload,
            );
          }

          final all = snapshot.data ?? const <NotificationItem>[];
          final items = _filter == 1 ? all.where((item) => !item.isRead).toList() : all;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(14.72, 7.36, 14.72, 33.12),
              children: [
                _UnreadSummary(items: all),
                const SizedBox(height: 14),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l10n.t('allNotifications')), icon: const Icon(Icons.notifications_none_rounded)),
                    ButtonSegment(value: 1, label: Text(l10n.t('unreadNotifications')), icon: const Icon(Icons.mark_email_unread_outlined)),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) => setState(() => _filter = value.first),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 10),
                        Text(l10n.t(_filter == 1 ? 'noUnreadNotifications' : 'noData'), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                else
                  for (final item in items) ...[
                    _NotificationCard(item: item, onTap: () => _markRead(item)),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UnreadSummary extends StatelessWidget {
  const _UnreadSummary({required this.items});
  final List<NotificationItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = items.where((item) => !item.isRead).length;
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(16.56),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(15.3)),
            child: Icon(Icons.notifications_active_rounded, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('notificationsCenter'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(l10n.t('unreadCount', {'count': '$unread'}), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13.8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.isRead ? cs.surfaceContainerHighest : cs.primaryContainer,
              borderRadius: BorderRadius.circular(12.6),
            ),
            child: Icon(
              item.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
              color: item.isRead ? cs.onSurfaceVariant : cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900))),
                    if (!item.isRead)
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.body, maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                if (item.publishAt?.isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  Text(item.publishAt!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({required this.icon, required this.title, required this.action, required this.onAction});
  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(25.76),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh_rounded), label: Text(action)),
            ],
          ),
        ),
      );
}
