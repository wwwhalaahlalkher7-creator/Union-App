import 'package:flutter/material.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  ApiClient? _client;
  NotificationsRepository? _repository;
  Future<List<NotificationItem>>? _future;

  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { try { _client = await AuthenticatedClient.create(); _repository = NotificationsRepository(_client!); final future = _repository!.list(); if (mounted) setState(() => _future = future); } catch (_) {} }
  @override void dispose() { _client?.dispose(); super.dispose(); }
  Future<void> _reload() async { final repo = _repository; if (repo == null) return; final future = repo.list(); setState(() => _future = future); await future; }

  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('notifications')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<List<NotificationItem>>(
        future: _future ?? Future.error(const ApiException('جارٍ تهيئة جلسة الطالب.')),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.t('connectionFailed'), textAlign: TextAlign.center)));
          final items = snapshot.data ?? const <NotificationItem>[];
          if (items.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.t('noData'), textAlign: TextAlign.center)));
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) { final item = items[index]; return Card(child: ListTile(leading: CircleAvatar(child: Icon(item.isRead ? Icons.notifications_none : Icons.notifications_active)), title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.w700)), subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Text(item.body, maxLines: 5, overflow: TextOverflow.ellipsis)), onTap: () async { if (!item.isRead) { final repo = _repository; if (repo == null) return; await repo.markRead([item.id]); if (mounted) setState(() => _future = repo.list()); } })); },
          );
        },
      ),
    );
  }
}
