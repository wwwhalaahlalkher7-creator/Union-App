import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/xp_snapshot.dart';
import '../../data/models/badge_item.dart';
import '../../data/repositories/badges_repository.dart';
import '../../data/repositories/xp_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/login_required_card.dart';
import '../../shared/widgets/app_section.dart';
import '../../shared/widgets/list_skeleton.dart';

class XpScreen extends StatefulWidget {
  const XpScreen({super.key});

  @override
  State<XpScreen> createState() => _XpScreenState();
}

class _XpScreenState extends State<XpScreen> {
  XpRepository? _repo;
  BadgesRepository? _badgesRepo;
  XpSnapshot? _snapshot;
  BadgeSnapshot? _badgeSnapshot;
  String? _error;
  String? _badgeError;
  bool _loading = true;
  bool _lastErrorIsAuth = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _badgeError = null;
      });
    }

    _repo ??= AppDependencies.instance.xp;
    _badgesRepo ??= AppDependencies.instance.badges;

    final xpFuture = _repo!.getXp();
    final badgesFuture = _badgesRepo!.getBadges();

    try {
      final snapshot = await xpFuture;
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (e) {
      if (mounted) {
        setState(() { _error = ErrorMessage.from(context, e, fallbackKey: 'xpLoadError'); _lastErrorIsAuth = e is ApiException && (e.kind == ApiErrorKind.auth || e.code == 'AUTH_REQUIRED'); });
      }
    }

    try {
      final badges = await badgesFuture;
      if (mounted) setState(() => _badgeSnapshot = badges);
    } catch (e) {
      if (mounted) {
        setState(() => _badgeError = ErrorMessage.from(context, e, fallbackKey: 'badgesLoadError'));
      }
    }

    if (mounted) setState(() => _loading = false);
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = _snapshot;

    Widget body;
    if (_loading && snapshot == null) {
      body = const ListSkeleton(count: 5);
    } else if (_error != null && snapshot == null) {
      body = (_lastErrorIsAuth) ? const LoginRequiredCard() : _XpError(message: _error!, retry: _load);
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
            _BadgeCollection(
              snapshot: _badgeSnapshot,
              error: _badgeError,
              retry: _load,
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

class _BadgeCollection extends StatelessWidget {
  const _BadgeCollection({required this.snapshot, required this.error, required this.retry});

  final BadgeSnapshot? snapshot;
  final String? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (snapshot == null) {
      if (error != null) {
        return AppCard(
          child: Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(error!, maxLines: 3, overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: retry, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        );
      }
      return const ListSkeleton(count: 2);
    }

    final data = snapshot!;
    final ratio = data.totalCount == 0 ? 0.0 : (data.earnedCount / data.totalCount).clamp(0.0, 1.0).toDouble();
    return AppSection(
      title: l10n.t('badgeCollection'),
      subtitle: l10n.t('badgesEarned', {'earned': '${data.earnedCount}', 'total': '${data.totalCount}'}),
      child: Column(
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.workspace_premium_rounded, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.t('badgesEarned', {'earned': '${data.earnedCount}', 'total': '${data.totalCount}'}), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: ratio, minHeight: 7, borderRadius: BorderRadius.circular(7)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 4 : (constraints.maxWidth >= 480 ? 3 : 2);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.badges.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: .88,
                ),
                itemBuilder: (context, index) => _BadgeCard(badge: data.badges[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});
  final BadgeItem badge;

  IconData _icon() => switch (badge.ruleType) {
    'xp_total' => Icons.bolt_rounded,
    'level' => Icons.trending_up_rounded,
    'completed_materials' => Icons.menu_book_rounded,
    'progress_events' => Icons.auto_stories_rounded,
    'learning_events' => Icons.event_available_rounded,
    'comments' => Icons.forum_outlined,
    'reactions' => Icons.thumb_up_alt_outlined,
    'replies' => Icons.reply_rounded,
    'completed_subjects' => Icons.school_rounded,
    _ => Icons.workspace_premium_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final description = badge.localizedDescription(languageCode);
    return AppCard(
      padding: const EdgeInsets.all(10),
      borderColor: badge.earned ? cs.primary.withValues(alpha: .34) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: badge.earned ? cs.primaryContainer : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon(), color: badge.earned ? cs.onPrimaryContainer : cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            badge.localizedName(languageCode),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, color: badge.earned ? cs.onSurface : cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5, height: 1.2),
          ),
          if (badge.earned) ...[
            const SizedBox(height: 4),
            Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
          ],
        ],
      ),
    );
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
