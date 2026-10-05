import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/comment_item.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/interactions_repository.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({required this.id, required this.type, super.key});
  final String id;
  final String type;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  ContentItem? _fresh;
  bool _loading = true;
  String? _error;
  bool _liked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final item = await ContentRepository().detail(widget.type, widget.id);
      if (!mounted) return;
      setState(() {
        _fresh = item;
        _liked = item.myReaction == 'like';
        _likeCount = item.likeCount;
        _commentCount = item.commentCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : AppLocalizations.of(context).t('connectionFailed');
      });
    }
  }

  Future<void> _like() async {
    if (_busy) return;
    final current = _fresh;
    if (current == null) return;
    setState(() => _busy = true);
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      final repo = InteractionsRepository(client);
      if (_liked) {
        await repo.unreact(widget.type, current.id);
        if (mounted) {
          setState(() { _liked = false; _likeCount = _likeCount > 0 ? _likeCount - 1 : 0; });
          _feedback(AppLocalizations.of(context).t('unlikeSuccess'));
        }
      } else {
        await repo.react(widget.type, current.id, 'like');
        if (mounted) {
          setState(() { _liked = true; _likeCount += 1; });
          _feedback(AppLocalizations.of(context).t('likeSuccess'));
        }
      }
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

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1400)));
  }

  @override
  Widget build(BuildContext context) {
    final item = _fresh;
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.type == 'news' ? l10n.t('news') : widget.type == 'achievement' ? l10n.t('achievements') : l10n.t('events'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(_error ?? l10n.t('connectionFailed'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _loadDetail, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.t('retry'))),
            ]),
          ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final images = item.images.isNotEmpty
        ? item.images
        : (item.imageUrl?.trim().isNotEmpty == true ? [item.imageUrl!] : const <String>[]);
    final label = widget.type == 'news'
        ? l10n.t('news')
        : widget.type == 'achievement'
            ? l10n.t('achievements')
            : l10n.t('events');

    final mediaTab = widget.type == 'achievement' ? 1 : widget.type == 'event' ? 2 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.type == 'achievement' && item.badge?.trim().isNotEmpty == true
              ? item.badge!
              : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () {
            // Return to the already-open MediaScreen instead of replacing it.
            // This preserves the exact tab (news/achievements/events) the
            // student came from. The fallback keeps direct/deep links safe.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/media?tab=$mediaTab');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 28),
        children: [
          if (images.isNotEmpty)
            _Gallery(images: images)
          else
            _Fallback(label: label, icon: widget.type == 'news' ? Icons.article_rounded : widget.type == 'achievement' ? Icons.emoji_events_rounded : Icons.event_available_rounded),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.35)),
                const SizedBox(height: 7),
                if (widget.type == 'event') ...[
                  if (item.eventAt != null) Text('${l10n.t('eventStart')}: ${_date(item.eventAt)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${l10n.t('eventEnd')}: ${item.endAt != null ? _date(item.endAt) : l10n.t('eventEndNotSet')}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ] else
                  Text(_date(item.eventAt ?? item.createdAt), style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
                if (item.location?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(item.location!, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
                ],
                if (item.body?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(item.body!, style: const TextStyle(fontSize: 13, height: 1.75)),
                ],
                if (widget.type == 'achievement' && item.highlights.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(item.highlightsTitle?.trim().isNotEmpty == true ? item.highlightsTitle! : l10n.t('highlights'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...item.highlights.map((highlight) => Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.check_circle_rounded, size: 17, color: cs.primary),
                      const SizedBox(width: 7),
                      Expanded(child: Text(highlight, style: const TextStyle(fontSize: 12, height: 1.55))),
                    ]),
                  )),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _like,
                      icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16),
                      label: Text('${_liked ? l10n.t('liked') : l10n.t('like')} $_likeCount'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openComments(context, item),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: Text('${l10n.t('comments')} $_commentCount'),
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

  Future<void> _openComments(BuildContext context, ContentItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContentCommentsSheet(item: item, type: widget.type, onCommentCountChanged: (count) {
        if (mounted) setState(() => _commentCount = count);
      }),
    );
    if (mounted) _loadDetail();
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
            cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
            filterQuality: FilterQuality.low,
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
                  cacheWidth: (MediaQuery.sizeOf(context).width / 3 * MediaQuery.devicePixelRatioOf(context)).round(),
                  filterQuality: FilterQuality.low,
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
  const ContentCommentsSheet({required this.item, required this.type, this.onCommentCountChanged, super.key});
  final ContentItem item;
  final String type;
  final ValueChanged<int>? onCommentCountChanged;

  @override
  State<ContentCommentsSheet> createState() => _ContentCommentsSheetState();
}

class _ContentCommentsSheetState extends State<ContentCommentsSheet> {
  ApiClient? _client;
  Future<List<CommentItem>>? _future;
  final _controller = TextEditingController();
  bool _sending = false;
  int _commentCount = 0;
  final Map<String, List<CommentItem>> _replies = <String, List<CommentItem>>{};
  final Set<String> _expandedReplies = <String>{};
  final Set<String> _loadingReplies = <String>{};

  @override
  void initState() {
    super.initState();
    _commentCount = widget.item.commentCount;
    _load();
  }

  void _load() {
    if (mounted) setState(() => _future = _fetch());
  }

  Future<List<CommentItem>> _fetch() async {
    _client ??= await AuthenticatedClient.create();
    final page = await InteractionsRepository(_client!).commentsPage(widget.type, widget.item.id);
    if (mounted) {
      setState(() => _commentCount = page.total);
      widget.onCommentCountChanged?.call(page.total);
    }
    return page.items;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).addComment(widget.type, widget.item.id, text);
      _controller.clear();
      if (mounted) {
        setState(() => _commentCount += 1);
        widget.onCommentCountChanged?.call(_commentCount);
        _feedback(AppLocalizations.of(context).t('commentSuccess'));
      }
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
      final repo = InteractionsRepository(client);
      if (comment.liked) {
        await repo.unreactComment(comment.id);
        if (mounted) {
          _replaceComment(comment.copyWith(liked: false, reactionCount: comment.reactionCount > 0 ? comment.reactionCount - 1 : 0));
          _feedback(AppLocalizations.of(context).t('unlikeSuccess'));
        }
      } else {
        await repo.reactComment(comment.id, 'like');
        if (mounted) {
          _replaceComment(comment.copyWith(liked: true, reactionCount: comment.reactionCount + 1));
          _feedback(AppLocalizations.of(context).t('likeSuccess'));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('commentReactionFailed'))));
    } finally {
      client?.dispose();
    }
  }

  void _replaceComment(CommentItem updated) {
    final future = _future;
    if (future == null) return;
    future.then((items) {
      if (!mounted) return;
      final next = items.map((item) => item.id == updated.id ? updated : item).toList();
      setState(() => _future = Future.value(next));
    });
  }

  Future<void> _toggleReplies(CommentItem comment) async {
    if (_expandedReplies.contains(comment.id)) {
      setState(() => _expandedReplies.remove(comment.id));
      return;
    }
    setState(() => _expandedReplies.add(comment.id));
    if (_replies.containsKey(comment.id)) return;
    setState(() => _loadingReplies.add(comment.id));
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      final rows = await InteractionsRepository(client).replies(comment.id);
      if (mounted) setState(() => _replies[comment.id] = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('connectionFailed'))));
    } finally {
      client?.dispose();
      if (mounted) setState(() => _loadingReplies.remove(comment.id));
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
      if (mounted) {
        _replies.remove(comment.id);
        _expandedReplies.add(comment.id);
        _loadingReplies.add(comment.id);
        _feedback(AppLocalizations.of(context).t('replySuccess'));
      }
      _load();
      try {
        final rows = await InteractionsRepository(client).replies(comment.id);
        if (mounted) setState(() => _replies[comment.id] = rows);
      } finally {
        if (mounted) setState(() => _loadingReplies.remove(comment.id));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('commentFailed'))));
    } finally {
      client?.dispose();
    }
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1400)));
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
                      final replies = _replies[comment.id] ?? const <CommentItem>[];
                      final expanded = _expandedReplies.contains(comment.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(comment.studentName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(comment.body, style: const TextStyle(fontSize: 11.5, height: 1.5)),
                          Row(
                            children: [
                              IconButton(visualDensity: VisualDensity.compact, onPressed: () => _react(comment), icon: Icon(comment.liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16, color: comment.liked ? cs.primary : cs.onSurfaceVariant)),
                              Text('${comment.reactionCount}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                              const SizedBox(width: 6),
                              TextButton(onPressed: () => _reply(comment), child: Text(l10n.t('reply'), style: const TextStyle(fontSize: 10))),
                              if (comment.replyCount > 0) ...[
                                const SizedBox(width: 2),
                                TextButton(onPressed: () => _toggleReplies(comment), child: Text('${comment.replyCount} ${l10n.t('replies')}', style: const TextStyle(fontSize: 10))),
                              ],
                            ],
                          ),
                          if (expanded) Padding(
                            padding: const EdgeInsetsDirectional.only(start: 24, bottom: 4),
                            child: _loadingReplies.contains(comment.id)
                                ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                                : replies.isEmpty
                                    ? Text(l10n.t('noReplies'), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))
                                    : Column(children: replies.map((reply) => Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                          Text(reply.studentName, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
                                          const SizedBox(height: 3),
                                          Text(reply.body, style: const TextStyle(fontSize: 10.5, height: 1.45)),
                                        ]),
                                      )).toList()),
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
