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

  Future<_SystemData> _load() async {
    _client ??= await AuthenticatedClient.create();

    final xp = await XpRepository(_client!).getXp();
    final badges = await BadgesRepository(_client!).getBadges();

    return _SystemData(xp, badges);
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

          final xp = snapshot.data!.xp;
          final badges = snapshot.data!.badges;

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

class _SystemData {
  const _SystemData(
    this.xp,
    this.badges,
  );

  final XpSnapshot xp;
  final BadgeSnapshot badges;
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
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 10.5,
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