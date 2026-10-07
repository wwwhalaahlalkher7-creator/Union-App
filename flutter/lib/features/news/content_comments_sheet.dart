part of 'content_detail_screen.dart';

class ContentCommentsSheet extends StatefulWidget {
  const ContentCommentsSheet({required this.item, required this.type, this.onCommentCountChanged, super.key});
  final ContentItem item;
  final String type;
  final ValueChanged<int>? onCommentCountChanged;

  @override
  State<ContentCommentsSheet> createState() => _ContentCommentsSheetState();
}

class _ContentCommentsSheetState extends State<ContentCommentsSheet> {
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
    final page = await AppDependencies.instance.interactions.commentsPage(widget.type, widget.item.id);
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
        await AppDependencies.instance.interactions.addComment(widget.type, widget.item.id, text);
      _controller.clear();
      if (mounted) {
        setState(() => _commentCount += 1);
        widget.onCommentCountChanged?.call(_commentCount);
        ActionFeedback.show(context, type: ActionFeedbackType.comment);
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'commentFailed'))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(CommentItem comment) async {
    try {
      final repo = AppDependencies.instance.interactions;
      if (comment.liked) {
        await repo.unreactComment(comment.id);
        if (mounted) {
          _replaceComment(comment.copyWith(liked: false, reactionCount: comment.reactionCount > 0 ? comment.reactionCount - 1 : 0));
          ActionFeedback.show(context, type: ActionFeedbackType.unlike);
        }
      } else {
        await repo.reactComment(comment.id, 'like');
        if (mounted) {
          _replaceComment(comment.copyWith(liked: true, reactionCount: comment.reactionCount + 1));
          ActionFeedback.show(context, type: ActionFeedbackType.like);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'commentReactionFailed'))));
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
    try {
      final rows = await AppDependencies.instance.interactions.replies(comment.id);
      if (mounted) setState(() => _replies[comment.id] = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'))));
    } finally {
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
    try {
      await AppDependencies.instance.interactions.addReply(comment.id, value);
      if (mounted) {
        _replies.remove(comment.id);
        _expandedReplies.add(comment.id);
        _loadingReplies.add(comment.id);
        ActionFeedback.show(context, type: ActionFeedbackType.reply);
      }
      _load();
      try {
        final rows = await AppDependencies.instance.interactions.replies(comment.id);
        if (mounted) setState(() => _replies[comment.id] = rows);
      } finally {
        if (mounted) setState(() => _loadingReplies.remove(comment.id));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'commentFailed'))));
    }
  }


  @override
  void dispose() {
    _controller.dispose();
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
                    final Object e = snapshot.error ?? Exception('Unknown error');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), textAlign: TextAlign.center),
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
