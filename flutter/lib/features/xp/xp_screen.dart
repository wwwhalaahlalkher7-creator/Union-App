import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/xp_snapshot.dart';
import '../../data/repositories/xp_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';
import '../../shared/widgets/list_skeleton.dart';

class XpScreen extends StatefulWidget {
  const XpScreen({super.key});

  @override
  State<XpScreen> createState() => _XpScreenState();
}

class _XpScreenState extends State<XpScreen> {
  ApiClient? _client;
  XpRepository? _repo;
  XpSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      _client ??= await AuthenticatedClient.create();
      _repo ??= XpRepository(_client!);
      final snapshot = await _repo!.getXp();
      if (mounted) setState(() { _snapshot = snapshot; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : AppLocalizations.of(context).t('xpLoadError'));
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
    final l10n = AppLocalizations.of(context);
    final snapshot = _snapshot;
    final progress = snapshot == null || snapshot.nextLevelXp <= 0
        ? 0.0
        : (snapshot.levelXp / snapshot.nextLevelXp).clamp(0.0, 1.0).toDouble();

    Widget body;
    if (_loading && snapshot == null) {
      body = const ListSkeleton(count: 5);
    } else if (_error != null && snapshot == null) {
      body = _XpError(message: _error!, retry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(14.72, 9.2, 14.72, 33.12),
          children: [
            AppCard(
              padding: const EdgeInsets.all(18.4),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.bolt_rounded, size: 36, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.t('xpValue', {'value': '${snapshot!.totalXp}'}), style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 3),
                  Text(l10n.t('levelValue', {'level': '${snapshot.level}'}), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.8),
                    child: LinearProgressIndicator(value: progress, minHeight: 10),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.t('xpNextLevel', {'current': '${snapshot.levelXp}', 'next': '${snapshot.nextLevelXp}'}), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppSection(
              title: l10n.t('xpLog'),
              subtitle: l10n.t('xpSubtitle'),
              child: snapshot.events.isEmpty
                  ? AppCard(child: Text(l10n.t('noXp')))
                  : Column(children: [for (var i = 0; i < snapshot.events.length; i++) _EventTile(event: snapshot.events[i], last: i == snapshot.events.length - 1)]),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('xpLevel')),
        actions: [IconButton(tooltip: l10n.t('refresh'), onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: body,
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.last});
  final XpEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                if (!last) Expanded(child: Container(width: 2, color: cs.outline.withValues(alpha: .35))),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                padding: const EdgeInsets.all(12.88),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_label(l10n, event.type), style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text('+${event.xp}', style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, String type) {
    switch (type) {
      case 'material_progress_25': return l10n.t('xpEvent25');
      case 'material_progress_50': return l10n.t('xpEvent50');
      case 'material_progress_75': return l10n.t('xpEvent75');
      case 'material_complete': return l10n.t('xpEventComplete');
      default: return l10n.t('xpEventOther');
    }
  }
}

class _XpError extends StatelessWidget {
  const _XpError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(25.76),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_outlined, size: 58, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(AppLocalizations.of(context).t('retry'))),
            ],
          ),
        ),
      );
}
