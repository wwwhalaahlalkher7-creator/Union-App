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
      // Do not hide a backend 4xx/5xx behind the two-item local fallback.
      // The fallback is reserved for genuine connectivity failures only, so
      // a broken badges deployment remains visible and debuggable.
      if (mounted) {
        final apiError = e is ApiException ? e : null;
        final canUseFallback = apiError?.kind == ApiErrorKind.offline ||
            apiError?.kind == ApiErrorKind.timeout;
        final currentXp = _snapshot;
        if (canUseFallback && currentXp != null) {
          setState(() {
            _badgeSnapshot = BadgesRepository.fallbackForXp(currentXp);
            _badgeError = null;
          });
        } else {
          setState(() => _badgeError = ErrorMessage.from(context, e, fallbackKey: 'badgesLoadError'));
        }
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
    final remaining = (snapshot.nextLevelXp - snapshot.levelXp).clamp(0, snapshot.nextLevelXp);

    return AppCard(
      padding: const EdgeInsets.all(DesignTokens.space20),
      borderColor: cs.primary.withValues(alpha: .25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _XpCircularProgress(progress: progress),
              const SizedBox(width: 18),
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
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(Icons.bolt_rounded, color: cs.onPrimaryContainer, size: 27),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _XpProgressBar(
            progress: progress,
            targetLabel: '${snapshot.nextLevelXp} XP',
            remainingLabel: l10n.t('xpRemaining', {'value': '$remaining'}),
          ),
        ],
      ),
    );
  }
}

class _XpCircularProgress extends StatelessWidget {
  const _XpCircularProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (progress * 100).round();
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              width: 74,
              height: 74,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _XpProgressBar extends StatelessWidget {
  const _XpProgressBar({
    required this.progress,
    required this.targetLabel,
    required this.remainingLabel,
  });

  final double progress;
  final String targetLabel;
  final String remainingLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: Text(
                remainingLabel,
                textAlign: TextAlign.start,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                targetLabel,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgeCollection extends StatelessWidget {
  const _BadgeCollection({required this.snapshot, required this.error, required this.retry});

  final BadgeSnapshot? snapshot;
  final String? error;
  final VoidCallback retry;

  IconData _categoryIcon(String icon) => switch (icon) {
    'bolt' => Icons.bolt_rounded,
    'trending_up' => Icons.trending_up_rounded,
    'menu_book' => Icons.menu_book_rounded,
    'school' => Icons.school_rounded,
    'auto_stories' => Icons.auto_stories_rounded,
    'event' => Icons.event_available_rounded,
    'comment' => Icons.forum_outlined,
    'thumb_up' => Icons.thumb_up_alt_outlined,
    'reply' => Icons.reply_rounded,
    _ => Icons.workspace_premium_rounded,
  };

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
    return AppSection(
      title: l10n.t('badgeCollection'),
      subtitle: l10n.t('badgesEarnedCount', {'earned': '${data.earnedCount}'}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.badges.isNotEmpty) ...[
            _BadgeSectionTitle(
              icon: Icons.workspace_premium_rounded,
              title: l10n.t('achievementsTitle'),
            ),
            const SizedBox(height: 10),
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
                    childAspectRatio: .92,
                  ),
                  itemBuilder: (context, index) => _EarnedBadgeCard(badge: data.badges[index]),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
          if (data.categories.isNotEmpty) ...[
            _BadgeSectionTitle(
              icon: Icons.lock_outline_rounded,
              title: l10n.t('badgesNext'),
            ),
            const SizedBox(height: 10),
            ...data.categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BadgeCategoryCard(
                  category: category,
                  icon: _categoryIcon(category.icon),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}



class _EarnedBadgeCard extends StatelessWidget {
  const _EarnedBadgeCard({required this.badge});
  final BadgeItem badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: cs.primary.withValues(alpha: .25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: cs.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            badge.localizedName(languageCode),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
        ],
      ),
    );
  }
}

class _BadgeSectionTitle extends StatelessWidget {
  const _BadgeSectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ],
    );
  }
}

class _BadgeCategoryCard extends StatelessWidget {
  const _BadgeCategoryCard({required this.category, required this.icon});
  final BadgeCategory category;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final next = category.next;
    final progress = category.progress;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: category.completed ? cs.primary.withValues(alpha: .30) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.completed ? cs.primaryContainer : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: category.completed ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      category.completed
                          ? l10n.t('badgeComplete')
                          : l10n.t('badgeNext'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (category.completed)
                Icon(Icons.check_circle_rounded, color: cs.primary),
            ],
          ),
          if (!category.completed && next != null) ...[
            const SizedBox(height: 12),
            _XpProgressBar(
              progress: progress,
              targetLabel: '${next.ruleValue}',
              remainingLabel: l10n.t('badgeRemaining', {'value': '${category.remaining}'}),
            ),
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
    final progress = snapshot.nextLevelXp <= 0
        ? 0.0
        : (snapshot.levelXp / snapshot.nextLevelXp).clamp(0.0, 1.0).toDouble();
    final isComplete = remaining == 0;

    return AppCard(
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                child: Text(
                  isComplete ? l10n.t('levelReady') : l10n.t('nextLevelGoal'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _XpProgressBar(
            progress: progress,
            targetLabel: '${snapshot.nextLevelXp} XP',
            remainingLabel: isComplete
                ? l10n.t('levelReadySubtitle')
                : l10n.t('xpRemaining', {'value': '$remaining'}),
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
