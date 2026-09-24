import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final ApiClient _client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
  late final ContentRepository _repo = ContentRepository();
  late Future<List<ContentItem>> _future = _repo.news();

  String _filter = 'all';

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _repo.news();
    setState(() => _future = future);
    await future;
  }

  void _openDetails(ContentItem item) {
    context.push('/news/detail', extra: item);
  }

  Future<void> _openComments(ContentItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsCommentsSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ContentItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Message(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : l10n.t('connectionFailed'),
              retry: () => setState(() => _future = _repo.news()),
            );
          }

          final items = snapshot.data ?? const <ContentItem>[];
          final visible = _filter == 'all'
              ? items
              : items
                  .where((item) =>
                      (item.category ?? '').toLowerCase() == _filter)
                  .toList();

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 88),
            children: [
              Text(
                l10n.t('news'),
                textAlign: TextAlign.start,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                l10n.t('newsSubtitle'),
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(l10n.t('all'), 'all', _filter, (value) => setState(() => _filter = value)),
                    _Chip(l10n.t('officialNews'), 'official', _filter, (value) => setState(() => _filter = value)),
                    _Chip(l10n.t('events'), 'event', _filter, (value) => setState(() => _filter = value)),
                    _Chip(l10n.t('activities'), 'activity', _filter, (value) => setState(() => _filter = value)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                AppCard(child: Text(l10n.t('noData'), textAlign: TextAlign.center))
              else
                for (final item in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NewsCard(
                      item: item,
                      onDetails: () => _openDetails(item),
                      onComments: () => _openComments(item),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.selectedValue, this.onChanged);

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 9.5)),
        selected: selectedValue == value,
        onSelected: (_) => onChanged(value),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      ),
    );
  }
}

class _NewsCard extends StatefulWidget {
  const _NewsCard({required this.item, required this.onDetails, required this.onComments});

  final ContentItem item;
  final VoidCallback onDetails;
  final VoidCallback onComments;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  ApiClient? _client;
  bool _liked = false;
  bool _reacting = false;
  int _likeDelta = 0;

  Future<void> _toggleLike() async {
    if (_reacting || _liked) return;
    setState(() => _reacting = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).react('news', widget.item.id, 'like');
      if (mounted) setState(() { _liked = true; _likeDelta = 1; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('likeFailed'))),
      );
    } finally {
      if (mounted) setState(() => _reacting = false);
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
    final item = widget.item;
    final imageUrl = item.imageUrl?.trim();
    final category = item.category?.trim().isNotEmpty == true
        ? item.category!.trim()
        : l10n.t('news');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 8.6,
                child: imageUrl == null || imageUrl.isEmpty
                    ? Container(
                        color: context.colors.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: Icon(Icons.article_rounded, size: 46, color: context.colors.primary),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: context.colors.surfaceContainerHigh,
                          alignment: Alignment.center,
                          child: Icon(Icons.image_not_supported_outlined, size: 42, color: context.colors.onSurfaceVariant),
                        ),
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : Container(
                                color: context.colors.surfaceContainerHigh,
                                alignment: Alignment.center,
                                child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                      ),
              ),
              PositionedDirectional(
                start: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      _date(item.createdAt ?? item.updatedAt),
                      style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 9.5),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // Only the news text opens the details screen. The surrounding card does not.
                Semantics(
                  button: true,
                  label: l10n.t('openNews'),
                  child: InkWell(
                    onTap: widget.onDetails,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.title,
                            textAlign: TextAlign.start,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.35),
                          ),
                          if (item.summary?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.summary!.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 12, height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.outline),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 3),
            child: Row(
              children: [
                _ActionButton(
                  tooltip: l10n.t('like'),
                  count: widget.item.likeCount + _likeDelta,
                  onPressed: _reacting ? null : _toggleLike,
                  icon: _liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  active: _liked,
                ),
                _ActionButton(
                  tooltip: l10n.t('comments'),
                  count: widget.item.commentCount,
                  onPressed: widget.onComments,
                  icon: Icons.chat_bubble_outline_rounded,
                ),
                const Spacer(),
                if (item.publisher?.trim().isNotEmpty == true)
                  Flexible(
                    child: Text(
                      item.publisher!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 9),
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


class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.tooltip, required this.count, required this.onPressed, required this.icon, this.active = false});

  final String tooltip;
  final int count;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.primary : context.colors.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(7, 5, 7, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime? date) {
  if (date == null) return '';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context).t('retry')),
          ),
        ],
      ),
    );
  }
}
