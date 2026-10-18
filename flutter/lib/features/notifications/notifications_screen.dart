import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/errors/app_error.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/login_required_card.dart';
import '../../shared/widgets/list_skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsRepository? _repository;
  Future<List<NotificationItem>>? _future;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _repository = AppDependencies.instance.notifications;
      final future = _repository!.list();
      setState(() => _future = future);
      unawaited(_markAllReadOnEntry(future));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _future = Future.error(error, stackTrace));
      }
    }
  }



  Future<void> _reload() async {
    final repo = _repository;
    if (repo == null) return;
    final future = repo.list();
    setState(() => _future = future);
    await future;
  }

  Future<void> _markAllReadOnEntry(Future<List<NotificationItem>> future) async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final items = await future;
      final unread = items.where((item) => !item.isRead).map((item) => item.id).toList(growable: false);
      if (unread.isEmpty) return;
      await repo.markRead(unread);
      if (mounted) setState(() => _future = repo.list());
    } catch (_) {
      // The list itself displays any load failure; read-state update can be retried on refresh.
    }
  }


  void _openNotification(NotificationItem item) {
    if (item.contentType == 'achievement' && (item.contentId?.isNotEmpty ?? false)) {
      context.push('/media/detail?type=achievement&id=${Uri.encodeComponent(item.contentId!)}');
      return;
    }
    if (item.contentType == 'schedule' || item.category == 'schedule') {
      context.push('/schedule');
      return;
    }
    if (item.contentType == 'material' || item.category == 'material') {
      context.push('/materials');
      return;
    }
    if (item.contentType == 'news' && (item.contentId?.isNotEmpty ?? false)) {
      context.push('/media/detail?type=news&id=${Uri.encodeComponent(item.contentId!)}');
      return;
    }
    if (item.contentType == 'activity' && (item.contentId?.isNotEmpty ?? false)) {
      context.push('/media/detail?type=activity&id=${Uri.encodeComponent(item.contentId!)}');
      return;
    }
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(item.title), content: SingleChildScrollView(child: Text(item.body)),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _deleteNotification(NotificationItem item) async {
    final repo = _repository;
    if (repo == null) return;
    final action = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          title: const Text('حذف'),
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    );
    if (action != true) return;
    try {
      await repo.delete(item.id);
      if (mounted) setState(() => _future = repo.list());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessage.from(context, error, fallbackKey: 'genericError'))),
      );
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
            final Object e = snapshot.error ?? Exception('Unknown error');
            if (e is ApiException && (e.kind == ApiErrorKind.auth || e.code == 'AUTH_REQUIRED')) return const LoginRequiredCard();
            return _StateView(icon: Icons.cloud_off_rounded, title: ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), action: l10n.t('retry'), onAction: _reload);
          }

          final all = snapshot.data ?? const <NotificationItem>[];
          final items = all;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(14.72, 7.36, 14.72, 33.12),
              children: [
                _UnreadSummary(items: all),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 10),
                        Text(l10n.t('noData'), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                else
                  for (final item in items) ...[
                    GestureDetector(
                      onTap: () => _openNotification(item),
                      onLongPress: () => _deleteNotification(item),
                      child: _NotificationCard(item: item),
                    ),
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
  const _NotificationCard({required this.item});
  final NotificationItem item;

  String _formatDateTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(13.8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12.6),
            ),
            child: Icon(
              item.category == 'schedule' ? Icons.calendar_month_rounded : item.category == 'material' ? Icons.menu_book_rounded : item.category == 'achievement' ? Icons.emoji_events_rounded : (item.isRead ? Icons.notifications_none_rounded : Icons.campaign_rounded),
              color: item.category == 'schedule' ? cs.primary : item.category == 'material' ? cs.tertiary : item.category == 'achievement' ? cs.secondary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.body, maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                if (item.publishAt?.isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  Text('النشر: ${_formatDateTime(item.publishAt!)}', style: Theme.of(context).textTheme.bodySmall),
                ],
                if (item.expiresAt?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('انتهاء الصلاحية: ${_formatDateTime(item.expiresAt!)}', style: Theme.of(context).textTheme.bodySmall),
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
