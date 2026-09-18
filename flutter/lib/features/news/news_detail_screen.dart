import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/comment_item.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../shared/widgets/app_card.dart';

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({required this.item, super.key});
  final ContentItem item;

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  ApiClient? _client;
  bool _liked = false;
  bool _reacting = false;

  Future<void> _toggleLike() async {
    setState(() => _reacting = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).react('news', widget.item.id, 'like');
      if (mounted) setState(() => _liked = true);
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
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    final imageUrl = item.imageUrl?.trim();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('newsDetails'))),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 28),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl?.isNotEmpty == true)
                  AspectRatio(
                    aspectRatio: 16 / 8,
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: Icon(Icons.image_not_supported_outlined, size: 42, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.category ?? l10n.t('news'), style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(item.title, textAlign: TextAlign.start, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.35)),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Text(_date(item.createdAt ?? item.updatedAt), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5)),
                          if (item.publisher?.isNotEmpty == true) ...[
                            const Spacer(),
                            Flexible(child: Text(item.publisher!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5))),
                          ],
                        ],
                      ),
                      if (item.body?.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Text(item.body!, textAlign: TextAlign.start, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                      ] else if (item.summary?.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Text(item.summary!, textAlign: TextAlign.start, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.7)),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: _reacting ? null : _toggleLike,
                          icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16),
                          label: Text(_liked ? l10n.t('liked') : l10n.t('like')),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => NewsCommentsSheet(item: item),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: Text(l10n.t('comments')),
                        ),
                      ),
                    ],
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

class NewsCommentsSheet extends StatefulWidget {
  const NewsCommentsSheet({required this.item, super.key});
  final ContentItem item;

  @override
  State<NewsCommentsSheet> createState() => _NewsCommentsSheetState();
}

class _NewsCommentsSheetState extends State<NewsCommentsSheet> {
  ApiClient? _client;
  Future<List<CommentItem>>? _comments;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final future = _fetchComments();
    setState(() => _comments = future);
    await future;
  }

  Future<List<CommentItem>> _fetchComments() async {
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
    try {
      return await InteractionsRepository(client).comments('news', widget.item.id);
    } finally {
      client.dispose();
    }
  }

  Future<void> _addComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).addComment('news', widget.item.id, text);
      _comment.clear();
      await _loadComments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('commentPublished'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('commentFailed'))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: .82,
      child: Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 34, height: 4, decoration: BoxDecoration(color: cs.outline, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 6),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded), visualDensity: VisualDensity.compact),
                  const Spacer(),
                  Text(l10n.t('comments'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Icon(Icons.chat_bubble_outline_rounded, color: cs.primary, size: 20),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline),
            Expanded(
              child: FutureBuilder<List<CommentItem>>(
                future: _comments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text(l10n.t('connectionFailed')));
                  final list = snapshot.data ?? const <CommentItem>[];
                  if (list.isEmpty) return Center(child: Text(l10n.t('noComments'), textAlign: TextAlign.center));
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 12, color: cs.outline),
                    itemBuilder: (_, index) {
                      final comment = list[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(comment.body, textAlign: TextAlign.start, style: const TextStyle(fontSize: 11.5, height: 1.45)),
                        subtitle: Text(comment.studentName, textAlign: TextAlign.start, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: TextField(controller: _comment, maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: l10n.t('writeComment'), isDense: true))),
                    const SizedBox(width: 6),
                    IconButton(onPressed: _sending ? null : _addComment, tooltip: l10n.t('publish'), icon: Icon(Icons.send_rounded, color: cs.primary)),
                  ],
                ),
              ),
            ),
          ],
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
