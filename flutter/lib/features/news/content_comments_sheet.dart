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
  final _composerFocus = FocusNode();
  bool _sending = false;
  String? _studentId;
  CommentItem? _replyingTo;
  int _commentCount = 0;
  final Map<String, List<CommentItem>> _replies = <String, List<CommentItem>>{};
  final Set<String> _expandedReplies = <String>{};
  final Set<String> _loadingReplies = <String>{};

  @override
  void initState() {
    super.initState();
    _commentCount = widget.item.commentCount;
    AppDependencies.instance.student.profile().then((profile) { if (mounted) setState(() => _studentId = profile.id); }, onError: (_) {});
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
    final target = _replyingTo;
    try {
      if (target == null) {
        await AppDependencies.instance.interactions.addComment(widget.type, widget.item.id, text);
      } else {
        await AppDependencies.instance.interactions.addReply(target.id, text);
      }
      _controller.clear();
      if (mounted) {
        setState(() {
          _commentCount += target == null ? 1 : 0;
          _replyingTo = null;
        });
        widget.onCommentCountChanged?.call(_commentCount);
        ActionFeedback.show(context, type: target == null ? ActionFeedbackType.comment : ActionFeedbackType.reply);
      }
      if (target == null) {
        _load();
      } else {
        _replies.remove(target.id);
        _expandedReplies.add(target.id);
        _loadingReplies.add(target.id);
        try {
          final rows = await AppDependencies.instance.interactions.replies(target.id);
          if (mounted) setState(() => _replies[target.id] = rows);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'))));
        } finally {
          if (mounted) setState(() => _loadingReplies.remove(target.id));
          _load();
        }
      }
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


  Future<void> _showCommentMenu(CommentItem comment, {required bool isReply}) async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.content_copy_rounded), title: Text(l10n.t('copy')), onTap: () => Navigator.pop(sheetContext, 'copy')),
        if (_studentId != null && comment.studentId == _studentId) ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l10n.t('delete')), iconColor: Theme.of(sheetContext).colorScheme.error, textColor: Theme.of(sheetContext).colorScheme.error, onTap: () => Navigator.pop(sheetContext, 'delete')),
        const SizedBox(height: 8),
      ])),
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: comment.body));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('copied'))));
    } else if (action == 'delete') {
      await _deleteOwnCommentOrReply(comment, isReply: isReply);
    }
  }

  Future<void> _deleteOwnCommentOrReply(CommentItem item, {required bool isReply}) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('chatDeleteTitle')),
        content: Text(l10n.t('chatDeleteConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.t('delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (isReply) {
        await AppDependencies.instance.interactions.deleteReply(item.id);
        for (final entry in _replies.entries.toList()) {
          _replies[entry.key] = entry.value.where((reply) => reply.id != item.id).toList();
        }
      } else {
        await AppDependencies.instance.interactions.deleteComment(item.id);
        if (mounted) {
          setState(() {
            _future = _future?.then((items) => items.where((comment) => comment.id != item.id).toList());
            _commentCount = _commentCount > 0 ? _commentCount - 1 : 0;
          });
          widget.onCommentCountChanged?.call(_commentCount);
          _replies.remove(item.id);
          _expandedReplies.remove(item.id);
        }
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('chatMessageDeleted'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'))));
    }
  }

  Future<void> _reply(CommentItem comment) async {
    setState(() => _replyingTo = comment);
    if (!_expandedReplies.contains(comment.id)) {
      await _toggleReplies(comment);
    }
    _composerFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }


  @override
  void dispose() {
    _controller.dispose();
    _composerFocus.dispose();
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
                          GestureDetector(onTap: comment.studentId.isEmpty ? null : () => context.push('/student/profile/${Uri.encodeComponent(comment.studentId)}?name=${Uri.encodeQueryComponent(comment.studentName)}'), child: Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 10, backgroundColor: cs.primaryContainer, child: Icon(Icons.person_rounded, size: 12, color: cs.onPrimaryContainer)), const SizedBox(width: 5), Flexible(child: Text(comment.studentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cs.primary, decoration: TextDecoration.underline)))])),
                          const SizedBox(height: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => _showCommentMenu(comment, isReply: false),
                            child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(comment.body, style: const TextStyle(fontSize: 11.5, height: 1.5))),
                          ),
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
                                          GestureDetector(onTap: reply.studentId.isEmpty ? null : () => context.push('/student/profile/${Uri.encodeComponent(reply.studentId)}?name=${Uri.encodeQueryComponent(reply.studentName)}'), child: Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 9, backgroundColor: cs.primaryContainer, child: Icon(Icons.person_rounded, size: 11, color: cs.onPrimaryContainer)), const SizedBox(width: 5), Flexible(child: Text(reply.studentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: cs.primary, decoration: TextDecoration.underline)))])),
                                          const SizedBox(height: 3),
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onLongPress: () => _showCommentMenu(reply, isReply: true),
                                            child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(reply.body, style: const TextStyle(fontSize: 10.5, height: 1.45))),
                                          ),
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_replyingTo != null) Container(
                    width: double.infinity, margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 7, bottom: 7),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .6), borderRadius: BorderRadius.circular(10), border: BorderDirectional(start: BorderSide(color: cs.primary, width: 3))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${l10n.t('replyingTo')} ${_replyingTo!.studentName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary)),
                        Text(_replyingTo!.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      ])),
                      IconButton(tooltip: l10n.t('cancel'), visualDensity: VisualDensity.compact, onPressed: _cancelReply, icon: const Icon(Icons.close_rounded, size: 18)),
                    ]),
                  ),
                  Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: TextField(controller: _controller, focusNode: _composerFocus, maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: l10n.t('writeComment'), isDense: true))),
                    IconButton(onPressed: _sending ? null : _send, icon: Icon(Icons.send_rounded, color: cs.primary)),
                  ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime? date) => date == null ? '' : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
