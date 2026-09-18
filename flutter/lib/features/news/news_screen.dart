import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final ApiClient _client = ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
  );

  late final ContentRepository _repo =
      ContentRepository(_client);

  late Future<List<ContentItem>> _future = _repo.news();

  String _filter = 'all';

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _repo.news();

    setState(() {
      _future = future;
    });

    await future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ContentItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _Message(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : l10n.t('connectionFailed'),
              retry: () => setState(
                () => _future = _repo.news(),
              ),
            );
          }

          final items =
              snapshot.data ?? const <ContentItem>[];

          final visible = _filter == 'all'
              ? items
              : items
                  .where(
                    (item) =>
                        (item.category ?? '')
                            .toLowerCase() ==
                        _filter,
                  )
                  .toList();

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              14.72,
              12,
              14.72,
              92,
            ),
            children: [
              const Text(
                'الأخبار',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 20.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'آخر الأخبار المنشورة من الرابطة',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 11),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip('الكل', 'all'),
                    _Chip('بيانات رسمية', 'official'),
                    _Chip('فعاليات', 'event'),
                    _Chip('أنشطة', 'activity'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                AppCard(
                  child: Text(
                    l10n.t('noData'),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final item in visible)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 10),
                    child: _Card(
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

  Widget _Chip(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsetsDirectional.only(start: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
          ),
        ),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.onTap,
  });

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.category ?? 'خبر',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _date(
                    item.createdAt ?? item.updatedAt,
                  ),
                  style: TextStyle(
                    color:
                        context.colors.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            if (item.summary?.isNotEmpty == true) ...[
              const SizedBox(height: 5),
              Text(
                item.summary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color:
                      context.colors.onSurfaceVariant,
                  fontSize: 10.8,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 12,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'فتح الخبر',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime? date) {
  if (date == null) return '';

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

class _Message extends StatelessWidget {
  const _Message({
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
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: Text(
              AppLocalizations.of(context).t('retry'),
            ),
          ),
        ],
      ),
    );
  }
}