import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/comment_item.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/interactions_repository.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({required this.item, required this.type, super.key});
  final ContentItem item;
  final String type;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  ContentItem? _fresh;
  bool _liked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.item.myReaction == 'like';
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final client = await AuthenticatedClient.create();
    try {
      final item = await ContentRepository().detail(widget.type, widget.item.id);
      if (mounted) setState(() { _fresh = item; _liked = item.myReaction == 'like'; });
    } catch (_) {
      // The list item is already usable; detail refresh is best-effort.
    } finally {
      client.dispose();
    }
  }

  Future<void> _like() async {
    if (_busy || _liked) return;
    setState(() => _busy = true);
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      await InteractionsRepository(client).react(widget.type, widget.item.id, 'like');
      if (mounted) setState(() => _liked = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('likeFailed'))),
        );
      }
    } finally {
      client?.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _fresh ?? widget.item;
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final images = item.images.isNotEmpty
        ? item.images
        : (item.imageUrl?.trim().isNotEmpty == true ? [item.imageUrl!] : const <String>[]);
    final label = widget.type == 'news'
        ? l10n.t('news')
        : widget.type == 'event'
            ? l10n.t('events')
            : l10n.t('activities');

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 28),
        children: [
          if (images.isNotEmpty)
            _Gallery(images: images)
          else
            _Fallback(label: label, icon: widget.type == 'news' ? Icons.article_rounded : widget.type == 'event' ? Icons.event_available_rounded : Icons.directions_run_rounded),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      item.category?.trim().isNotEmpty == true ? item.category! : label,
                      style: TextStyle(color: cs.onPrimaryContainer, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.35)),
                const SizedBox(height: 7),
                Text(_date(item.eventAt ?? item.createdAt), style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
                if (item.location?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(item.location!, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
                ],
                if (item.body?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(item.body!, style: const TextStyle(fontSize: 13, height: 1.75)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _like,
                      icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16),
                      label: Text('${l10n.t('like')} ${item.likeCount + (_liked ? 1 : 0)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openComments(context, item),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: Text('${l10n.t('comments')} ${item.commentCount}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context, ContentItem item) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContentCommentsSheet(item: item, type: widget.type),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.images});
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            images.first,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _Fallback(label: '', icon: Icons.broken_image_outlined),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
              ),
              itemCount: images.length - 1,
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  images[index + 1],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 190,
      color: cs.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cs.primary),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: cs.primary)),
            ],
          ],
        ),
      ),
    );
  }
}

class ContentCommentsSheet extends StatefulWidget {
  const ContentCommentsSheet({required this.item, required this.type, super.key});
  final ContentItem item;
  final String type;

  @override
  State<ContentCommentsSheet> createState() => _ContentCommentsSheetState();
}

class _ContentCommentsSheetState extends State<ContentCommentsSheet> {
  ApiClient? _client;
  Future<List<CommentItem>>? _future;
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (mounted) setState(() => _future = _fetch());
  }

  Future<List<CommentItem>> _fetch() async {
    _client ??= await AuthenticatedClient.create();
    return InteractionsRepository(_client!).comments(widget.type, widget.item.id);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).addComment(widget.type, widget.item.id, text);
      _controller.clear();
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('commentFailed'))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(CommentItem comment) async {
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      await InteractionsRepository(client).reactComment(comment.id, 'like');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('commentReactionFailed'))));
    } finally {
      client?.dispose();
    }
  }

  Future<void> _reply(CommentItem comment) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('reply')),
        content: TextField(controller: controller, maxLines: 4, decoration: InputDecoration(hintText: l10n.t('writeReply'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(l10n.t('publish'))),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      await InteractionsRepository(client).addReply(comment.id, value);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('commentFailed'))));
    } finally {
      client?.dispose();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: .72,
      minChildSize: .45,
      maxChildSize: .92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
              child: Row(
                children: [
                  Text(l10n.t('comments'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 19)),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline),
            Expanded(
              child: FutureBuilder<List<CommentItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) {
                    final e = snapshot.error;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(e is ApiException ? e.message : l10n.t('connectionFailed'), textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(l10n.t('retry'))),
                          ],
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? const <CommentItem>[];
                  if (list.isEmpty) return Center(child: Text(l10n.t('noComments')));
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 16, color: cs.outline),
                    itemBuilder: (context, index) {
                      final comment = list[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(comment.studentName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(comment.body, style: const TextStyle(fontSize: 11.5, height: 1.5)),
                          Row(
                            children: [
                              IconButton(visualDensity: VisualDensity.compact, onPressed: () => _react(comment), icon: const Icon(Icons.thumb_up_alt_outlined, size: 16)),
                              Text('${comment.reactionCount}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                              const SizedBox(width: 8),
                              TextButton(onPressed: () => _reply(comment), child: Text(l10n.t('reply'), style: const TextStyle(fontSize: 10))),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: TextField(controller: _controller, maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: l10n.t('writeComment'), isDense: true))),
                    IconButton(onPressed: _sending ? null : _send, icon: Icon(Icons.send_rounded, color: cs.primary)),
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

String _date(DateTime? date) => date == null ? '' : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
