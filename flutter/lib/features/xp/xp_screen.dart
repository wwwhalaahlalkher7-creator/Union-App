import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
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
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : AppLocalizations.of(context).t('xpLoadError'),
        );
      }
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

    Widget body;
    if (_loading && snapshot == null) {
      body = const ListSkeleton(count: 5);
    } else if (_error != null && snapshot == null) {
      body = _XpError(message: _error!, retry: _load);
    } else {
      // Both guarded branches above require a null snapshot, so reaching this
      // branch means a snapshot is available. Keep the promotion explicit for
      // Dart's flow analysis and pass a non-null value to the child widgets.
      final data = snapshot!;
      final progress = data.nextLevelXp <= 0
          ? 0.0
          : (data.levelXp / data.nextLevelXp)
              .clamp(0.0, 1.0)
              .toDouble();

      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            DesignTokens.space16,
            DesignTokens.space12,
            DesignTokens.space16,
            DesignTokens.space32,
          ),
          children: [
            _XpHero(snapshot: data, progress: progress),
            const SizedBox(height: DesignTokens.space16),
            _NextMilestone(snapshot: data),
            const SizedBox(height: DesignTokens.space24),
            AppSection(
              title: l10n.t('xpLog'),
              subtitle: l10n.t('xpSubtitle'),
              child: data.events.isEmpty
                  ? AppCard(
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.t('noXp'))),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < data.events.length; i++)
                          _EventTile(
                            event: data.events[i],
                            last: i == data.events.length - 1,
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
        title: Text(l10n.t('xpLevel')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}

class _XpHero extends StatelessWidget {
  const _XpHero({required this.snapshot, required this.progress});

  final XpSnapshot snapshot;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AppCard(
      padding: const EdgeInsets.all(DesignTokens.space20),
      borderColor: cs.primary.withValues(alpha: .25),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(Icons.bolt_rounded,
                    color: cs.onPrimaryContainer, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('levelValue', {'level': '${snapshot.level}'}),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('xpValue', {'value': '${snapshot.totalXp}'}),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.t('xpNextLevel', {
                'current': '${snapshot.levelXp}',
                'next': '${snapshot.nextLevelXp}',
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Container(
                  width: 2,
                  height: 66,
                  color: cs.outlineVariant,
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _label(l10n, event.type),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '+${event.xp}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _label(AppLocalizations l10n, String type) {
    switch (type) {
      case 'material_progress_25':
        return l10n.t('xpEvent25');
      case 'material_progress_50':
        return l10n.t('xpEvent50');
      case 'material_progress_75':
        return l10n.t('xpEvent75');
      case 'material_complete':
        return l10n.t('xpEventComplete');
      default:
        return l10n.t('xpEventOther');
    }
  }
}


class _NextMilestone extends StatelessWidget {
  const _NextMilestone({required this.snapshot});
  final XpSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final remaining = (snapshot.nextLevelXp - snapshot.levelXp).clamp(0, snapshot.nextLevelXp);
    final isComplete = remaining == 0;

    return AppCard(
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isComplete ? Icons.check_rounded : Icons.flag_rounded,
              color: cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? l10n.t('levelReady')
                      : l10n.t('nextLevelGoal'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isComplete
                      ? l10n.t('levelReadySubtitle')
                      : l10n.t('xpRemaining', {'value': '$remaining'}),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpError extends StatelessWidget {
  const _XpError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).t('retry')),
              ),
            ],
          ),
        ),
      );
}
