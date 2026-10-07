import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/content_item.dart';
import '../../data/models/student_profile.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/list_skeleton.dart';
import '../../features/eino/eino_face.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _homeNewsLimit = 3;
  Future<_HomeData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final newsFuture = AppDependencies.instance.content.news();

    final studentRepo = AppDependencies.instance.student;
    final profileFuture = studentRepo.profile();
    final statsFuture = studentRepo.stats();

    final values = await Future.wait<dynamic>([
      newsFuture,
      profileFuture,
      statsFuture,
    ]);

    return _HomeData(
      values[0] as List<ContentItem>,
      values[1] as StudentProfile,
      values[2] as Map<String, dynamic>,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        final future = _load();
        setState(() => _future = future);
        await future;
      },
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton(count: 4);
          }

          if (snapshot.hasError) {
            final Object e = snapshot.error ?? Exception('Unknown error');
            return _StateMessage(
              message: ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'),
              retry: e is ApiException && !e.retryable ? null : () => setState(() => _future = _load()),
            );
          }

          final data = snapshot.data!;
          final xp = int.tryParse(
                '${data.stats['xp_total'] ?? 0}',
              ) ??
              0;
          final level = int.tryParse(
                '${data.stats['level'] ?? 1}',
              ) ??
              1;

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DesignTokens.space16,
              DesignTokens.space16,
              DesignTokens.space16,
              96,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(DesignTokens.space20),
                borderColor: context.colors.primary.withValues(alpha: .28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.t('hello', {'name': data.profile.name.split(' ').first}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.profile.departmentName ?? 'TRINEX',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickStat(
                            l10n.t('levelShort'),
                            '$level',
                            context.colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickStat(
                            'XP',
                            '$xp',
                            context.colors.secondary,
                            onTap: () => context.push('/xp'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickStat(
                            l10n.t('semesterShort'),
                            data.profile.semesterName ?? '—',
                            context.colors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space24),
              Text(
                l10n.t('quickAccess'),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      l10n.t('materials'),
                      Icons.menu_book_rounded,
                      context.colors.secondary,
                      () => context.go('/materials'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      l10n.t('media'),
                      Icons.newspaper_rounded,
                      context.colors.primary,
                      () => context.go('/media'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      l10n.t('favorites'),
                      Icons.favorite_border_rounded,
                      context.colors.tertiary,
                      () => context.push('/favorites'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space16),
              _EinoHomeCard(
                onTap: () => context.push('/eino?from=home'),
              ),
              const SizedBox(height: DesignTokens.space16),
              _ProgressJourneyCard(
                level: level,
                xp: xp,
                onXpTap: () => context.push('/xp'),
                onMaterialsTap: () => context.go('/materials'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    l10n.t('newsLatest'),
                    style: const TextStyle(
                      fontSize: 20.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.article_outlined,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data.news.isEmpty)
                AppCard(
                  child: Text(
                    l10n.t('noData'),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final item in data.news.take(_HomeScreenState._homeNewsLimit))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _NewsTile(
                      item: item,
                      onTap: () => context.push(
                        '/media/detail?type=news&id=${Uri.encodeQueryComponent(item.id)}',
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData(
    this.news,
    this.profile,
    this.stats,
  );

  final List<ContentItem> news;
  final StudentProfile profile;
  final Map<String, dynamic> stats;
}

class _QuickStat extends StatelessWidget {
  const _QuickStat(
    this.label,
    this.value,
    this.color, {
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: content,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.title,
    this.icon,
    this.color,
    this.onTap,
  );

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radius16),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          border: Border.all(
            color: context.colors.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({
    required this.item,
    required this.onTap,
  });

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      semanticLabel: item.title,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
            ),
            child: Icon(Icons.campaign_rounded, color: context.colors.primary, size: 23),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  if (item.summary?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    required this.retry,
  });

  final String message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 50,
              color: context.colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (retry != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).t('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EinoHomeCard extends StatelessWidget {
  const _EinoHomeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: cs.primaryContainer.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(DesignTokens.radius20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
          child: Row(
            children: [
              const EinoFace(size: 58, mood: EinoMood.happy, showAura: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('einoCardTitle'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(l10n.t('einoHomeSubtitle'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressJourneyCard extends StatelessWidget {
  const _ProgressJourneyCard({required this.level, required this.xp, required this.onXpTap, required this.onMaterialsTap});
  final int level;
  final int xp;
  final VoidCallback onXpTap;
  final VoidCallback onMaterialsTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: cs.onPrimaryContainer)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.t('yourJourney'), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(l10n.t('levelValue', {'level': '$level'}), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
            ])),
            Text('$xp XP', style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _JourneyAction(icon: Icons.bolt_rounded, label: l10n.t('viewXp'), onTap: onXpTap)),
            const SizedBox(width: 8),
            Expanded(child: _JourneyAction(icon: Icons.menu_book_rounded, label: l10n.t('materials'), onTap: onMaterialsTap)),
          ]),
        ],
      ),
    );
  }
}

class _JourneyAction extends StatelessWidget {
  const _JourneyAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), padding: const EdgeInsets.symmetric(horizontal: 10)));
}
