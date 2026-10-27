import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/badge_item.dart';
import '../../data/models/xp_snapshot.dart';
import '../../data/repositories/badges_repository.dart';
import '../../data/repositories/xp_repository.dart';
import '../../shared/widgets/app_card.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  ApiClient? _client;
  late Future<_SystemData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LoadResult<T>> _safeLoad<T>(Future<T> future) async {
    try {
      return _LoadResult.ok(await future);
    } catch (error) {
      return _LoadResult.error(error);
    }
  }

  Future<_SystemData> _load() async {
    _client ??= await AuthenticatedClient.create();
    final results = await Future.wait([
      _safeLoad<XpSnapshot>(XpRepository(_client!).getXp()),
      _safeLoad<BadgeSnapshot>(BadgesRepository(_client!).getBadges()),
    ]);
    final xpResult = results[0] as _LoadResult<XpSnapshot>;
    final badgesResult = results[1] as _LoadResult<BadgeSnapshot>;
    return _SystemData(
      xpResult.value ?? const XpSnapshot(totalXp: 0, level: 1, levelXp: 0, nextLevelXp: 100, events: []),
      badgesResult.value ?? const BadgeSnapshot(badges: [], earnedCount: 0, totalCount: 0, newlyAwarded: []),
      xpError: xpResult.error,
      badgesError: badgesResult.error,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });

    await _future;
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<_SystemData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _Msg(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : AppLocalizations.of(context).t('connectionFailed'),
              retry: _reload,
            );
          }

          final data = snapshot.data!;
          final xp = data.xp;
          final badges = data.badges;

          final denom = xp.nextLevelXp <= 0
              ? 1
              : xp.nextLevelXp;

          final progress =
              (xp.levelXp / denom).clamp(0, 1).toDouble();

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              14.72,
              12,
              14.72,
              92,
            ),
            children: [
              if (data.xpError != null || data.badgesError != null)
                AppCard(
                  child: Text(
                    data.xpError != null && data.badgesError != null
                        ? 'تعذر تحديث بعض بيانات النظام. حاول التحديث مرة أخرى.'
                        : data.xpError != null
                            ? 'تعذر تحديث بيانات XP حاليًا.'
                            : 'تعذر تحديث الشارات حاليًا.',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 10.5),
                  ),
                ),
              if (data.xpError != null || data.badgesError != null) const SizedBox(height: 10),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'نظام الإنجاز',
                      style: TextStyle(
                        fontSize: 19.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المستوى ${xp.level} • ${xp.totalXp} XP',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'XP المستوى: ${xp.levelXp} / ${xp.nextLevelXp}',
                      style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'الشارات',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${badges.earnedCount} من ${badges.totalCount} مكتسبة',
                      style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final badge in badges.badges)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _Badge(badge),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadResult<T> {
  const _LoadResult.ok(this.value) : error = null;
  const _LoadResult.error(this.error) : value = null;
  final T? value;
  final Object? error;
}

class _SystemData {
  const _SystemData(this.xp, this.badges, {this.xpError, this.badgesError});
  final XpSnapshot xp;
  final BadgeSnapshot badges;
  final Object? xpError;
  final Object? badgesError;
}

class _Badge extends StatelessWidget {
  const _Badge(this.b);

  final BadgeItem b;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            b.earned
                ? Icons.emoji_events_rounded
                : Icons.lock_outline_rounded,
            size: 20,
            color: b.earned
                ? context.colors.primary
                : context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              b.localizedName(
                Localizations.localeOf(context).languageCode,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 9.8,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (b.earned)
            Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: context.colors.primary,
            ),
        ],
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  const _Msg({
    required this.message,
    required this.retry,
  });

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              AppLocalizations.of(context).t('retry'),
            ),
          ),
        ],
      ),
    );
  }
}