import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/content_item.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../shared/widgets/app_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ApiClient? _client;
  Future<_HomeData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final publicClient = ApiClient(
      baseUrl: AppConstants.apiBaseUrl,
    );

    try {
      final newsFuture = ContentRepository(publicClient).news();

      _client ??= await AuthenticatedClient.create();

      final studentRepo = StudentRepository(_client!);
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
    } finally {
      publicClient.dispose();
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            final e = snapshot.error;
            return _StateMessage(
              message: e is ApiException ? e.message : l10n.t('connectionFailed'),
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
              20,
              18,
              20,
              92,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'مرحباً ${data.profile.name.split(' ').first} 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
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
                            'المستوى',
                            '$level',
                            context.colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickStat(
                            'XP',
                            '$xp',
                            context.colors.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickStat(
                            'الفصل',
                            data.profile.semesterName ?? '—',
                            context.colors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'الوصول السريع',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 20.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      'المواد',
                      Icons.menu_book_rounded,
                      context.colors.secondary,
                      () => context.go('/materials'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tile(
                      'الجداول',
                      Icons.calendar_month_rounded,
                      context.colors.primary,
                      () => context.go('/schedule'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tile(
                      'نظام XP',
                      Icons.workspace_premium_rounded,
                      context.colors.tertiary,
                      () => context.go('/xp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'أحدث الأخبار',
                    style: TextStyle(
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
                for (final item in data.news.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _NewsTile(
                      item: item,
                      onTap: () => context.push(
                        '/news/detail',
                        extra: item,
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
    this.color,
  );

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: context.colors.outline,
        ),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 27,
            ),
            const SizedBox(height: 7),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.campaign_rounded, color: context.colors.primary, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
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