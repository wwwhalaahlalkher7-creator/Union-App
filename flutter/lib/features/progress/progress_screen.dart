import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/material_progress.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';
import '../../shared/widgets/list_skeleton.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ApiClient? _client;
  ProgressRepository? _repo;
  ProgressSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      _client ??= await AuthenticatedClient.create();
      _repo ??= ProgressRepository(_client!);
      final snapshot = await _repo!.getProgress();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : AppLocalizations.of(context).t('progressLoadError'));
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
    final summary = snapshot?.summary ?? const <String, dynamic>{};
    final started = int.tryParse('${summary['started'] ?? 0}') ?? 0;
    final completed = int.tryParse('${summary['completed'] ?? 0}') ?? 0;
    final seconds = int.tryParse('${summary['active_seconds'] ?? 0}') ?? 0;

    Widget body;
    if (_loading && snapshot == null) {
      body = const ListSkeleton(count: 6);
    } else if (_error != null && snapshot == null) {
      body = _ErrorView(message: _error!, retry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(14.72, 9.2, 14.72, 33.12),
          children: [
            AppCard(
              padding: const EdgeInsets.all(16.56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('progressSummary'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(l10n.t('progressRealActivity'), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 540;
                      final cards = [
                        _StatCard(label: l10n.t('filesStarted'), value: '$started', icon: Icons.play_circle_outline_rounded),
                        _StatCard(label: l10n.t('filesCompleted'), value: '$completed', icon: Icons.check_circle_outline_rounded),
                        _StatCard(label: l10n.t('activeMinutes'), value: '${seconds ~/ 60}', icon: Icons.timer_outlined),
                      ];
                      if (wide) return Row(children: [for (var i = 0; i < cards.length; i++) Expanded(child: Padding(padding: EdgeInsetsDirectional.only(end: i == cards.length - 0.92 ? 0 : 7.36), child: cards[i]))]);
                      return Wrap(spacing: 8, runSpacing: 8, children: cards.map((card) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: card)).toList());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppSection(
              title: l10n.t('recentFiles'),
              child: snapshot == null || snapshot.items.isEmpty
                  ? AppCard(child: Text(l10n.t('noProgress')))
                  : Column(children: [for (final item in snapshot.items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ProgressTile(item: item))]),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('studyProgress')), actions: [IconButton(tooltip: l10n.t('refresh'), onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      body: body,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12.88, horizontal: 7.36),
        child: Column(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 20.2, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)],),
      );
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.item});
  final MaterialProgress item;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = item.materialTitle?.isNotEmpty == true ? item.materialTitle! : l10n.t('studyFile');
    final percent = item.percent.clamp(0, 100);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))), Text('$percent%', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary))]),
        if (item.subjectName?.isNotEmpty == true) ...[const SizedBox(height: 4), Text(item.subjectName!, style: Theme.of(context).textTheme.bodySmall)],
        const SizedBox(height: 11),
        LinearProgressIndicator(value: percent.toDouble() / 100, minHeight: 8, borderRadius: BorderRadius.circular(7.2)),
        const SizedBox(height: 8),
        Row(children: [Icon(item.completed ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 16, color: item.completed ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 5), Text(item.completed ? l10n.t('completed') : l10n.t('inProgress'), style: Theme.of(context).textTheme.bodySmall)]),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(22.08), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(AppLocalizations.of(context).t('retry')))])));
}
