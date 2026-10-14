import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/general_chat_repository.dart';
import '../../shared/widgets/app_card.dart';

class GeneralChatScreen extends StatefulWidget {
  const GeneralChatScreen({super.key});

  @override
  State<GeneralChatScreen> createState() => _GeneralChatScreenState();
}

class _GeneralChatScreenState extends State<GeneralChatScreen> {
  final GeneralChatRepository _repository = AppDependencies.instance.generalChat;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  Timer? _pollTimer;
  String? _studentId;
  bool _isModerator = false;
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  String? _loadError;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshMessages(silent: true));
  }

  Future<void> _initialLoad() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      final StudentProfile profile = await AppDependencies.instance.student.profile();
      _studentId = profile.id;
      _isModerator = profile.isModerator;
      final messages = await _repository.messages();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
        _loadError = null;
      });
      _scrollToBottom(jump: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = AppLocalizations.of(context).t('chatLoadFailed');
      });
    }
  }

  Future<void> _refreshMessages({bool silent = false}) async {
    if (_refreshing || _loading || !mounted) return;
    _refreshing = true;
    final wasNearBottom = !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent - _scrollController.position.pixels < 100;
    try {
      final messages = await _repository.messages();
      if (!mounted) return;
      final oldIds = _messages.map((m) => '${m['id']}').join('|');
      final newIds = messages.map((m) => '${m['id']}').join('|');
      final changed = oldIds != newIds;
      if (changed) {
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
          _loadError = null;
        });
        if (wasNearBottom) _scrollToBottom();
      } else if (_loadError != null) {
        setState(() => _loadError = null);
      }
    } catch (_) {
      if (!silent && mounted) _showSnack(AppLocalizations.of(context).t('chatLoadFailed'));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      final target = _replyingTo;
      final message = await _repository.send(text, replyToMessageId: target == null ? null : '${target['id']}');
      if (!mounted) return;
      _composer.clear();
      setState(() {
        _replyingTo = null;
        if (!_messages.any((m) => m['id'] == message['id'])) _messages.add(message);
        _loadError = null;
      });
      _scrollToBottom();
      _focusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('CHAT_RATE_LIMITED')
          ? l10n.t('chatSlowDown')
          : e.toString().contains('CHAT_MESSAGE_TOO_LONG')
              ? l10n.t('chatMessageTooLong')
              : l10n.t('chatSendFailed');
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }


  Future<void> _showMessageMenu(Map<String, dynamic> message, {required bool mine}) async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.reply_rounded), title: Text(l10n.t('reply')), onTap: () => Navigator.pop(sheetContext, 'reply')),
          ListTile(leading: const Icon(Icons.content_copy_rounded), title: Text(l10n.t('copy')), onTap: () => Navigator.pop(sheetContext, 'copy')),
          if (mine || _isModerator) ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(mine ? l10n.t('delete') : 'حذف الرسالة (إشراف)'), iconColor: Theme.of(sheetContext).colorScheme.error, textColor: Theme.of(sheetContext).colorScheme.error, onTap: () => Navigator.pop(sheetContext, 'delete')),
          if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l10n.t('chatReport')), onTap: () => Navigator.pop(sheetContext, 'report')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reply') { _startReply(message); return; }
    if (action == 'delete') { await _deleteMessage(message); return; }
    if (action == 'report') { await _reportMessage(message); return; }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: '${message['body'] ?? ''}'));
      if (mounted) _showSnack(l10n.t('copied'));
    }
  }

  void _startReply(Map<String, dynamic> message) {
    if ('${message['id'] ?? ''}'.isEmpty) return;
    setState(() => _replyingTo = Map<String, dynamic>.from(message));
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
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
      await _repository.delete('${message['id']}');
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == message['id']));
      _showSnack(l10n.t('chatMessageDeleted'));
    } catch (_) {
      if (mounted) _showSnack(l10n.t('chatActionFailed'));
    }
  }

  Future<void> _reportMessage(Map<String, dynamic> message) async {
    final l10n = AppLocalizations.of(context);
    const reasons = <String, String>{
      'spam': 'chatReportSpam',
      'harassment': 'chatReportHarassment',
      'inappropriate': 'chatReportInappropriate',
      'other': 'chatReportOther',
    };
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.t('chatReportTitle')),
        children: reasons.entries.map((entry) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, entry.key),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(l10n.t(entry.value))),
        )).toList(),
      ),
    );
    if (reason == null) return;
    try {
      await _repository.report('${message['id']}', reason: reason);
      if (mounted) _showSnack(l10n.t('chatReportSent'));
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().contains('CHAT_ALREADY_REPORTED') ? l10n.t('chatAlreadyReported') : l10n.t('chatActionFailed'));
    }
  }

  void _openStudent(Map<String, dynamic> message) {
    final id = '${message['studentId'] ?? message['student_id'] ?? message['authorStudentId'] ?? message['author_student_id'] ?? message['userId'] ?? message['user_id'] ?? ''}'.trim();
    if (id.isEmpty) {
      _showSnack(AppLocalizations.of(context).t('studentProfileUnavailable'));
      return;
    }
    final name = '${message['fullName'] ?? message['full_name'] ?? message['studentName'] ?? message['student_name'] ?? ''}'.trim();
    final department = '${message['departmentName'] ?? message['department_name'] ?? ''}'.trim();
    final semester = '${message['semesterName'] ?? message['semester_name'] ?? ''}'.trim();
    context.push('/student/profile/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(name)}&department=${Uri.encodeQueryComponent(department)}&semester=${Uri.encodeQueryComponent(semester)}');
  }

  void _jumpToMessage(String id) {
    final key = _messageKeys[id];
    final target = key?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOut, alignment: .35);
    } else {
      _showSnack(AppLocalizations.of(context).t('messageUnavailable'));
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(end);
      } else {
        _scrollController.animateTo(end, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.t('generalChat')),
          Text(l10n.t('chatOnlineSpace'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        actions: [IconButton(tooltip: l10n.t('refresh'), onPressed: () => _refreshMessages(), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: scheme.secondaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.shield_outlined, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.t('chatSafetyNotice'), style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12, height: 1.35))),
          ]),
        ),
        Expanded(child: _buildMessageArea(context)),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(color: scheme.surface, border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyingTo != null) _buildReplyComposerPreview(context, _replyingTo!),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: l10n.t('chatInputHint'),
                    counterText: '',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: .45),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: FilledButton(
                  onPressed: _sending ? null : _sendMessage,
                  style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                  child: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildMessageArea(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null && _messages.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: AppCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_outlined, size: 38, color: scheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _initialLoad, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.t('retry'))),
      ]))));
    }
    if (_messages.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 76, height: 76, decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.forum_outlined, size: 38, color: scheme.onPrimaryContainer)),
        const SizedBox(height: 14),
        Text(l10n.t('chatEmptyTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(l10n.t('chatEmptySubtitle'), style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
      ])));
    }
    return RefreshIndicator(
      onRefresh: () => _refreshMessages(),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: _messages.map((message) => _messageBubble(context, message)).toList(),
      ),
    );
  }

  Widget _messageBubble(BuildContext context, Map<String, dynamic> message) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final senderId = '${message['studentId'] ?? message['student_id'] ?? ''}';
    final mine = senderId.isNotEmpty && senderId == _studentId;
    final name = '${message['fullName'] ?? message['full_name'] ?? l10n.t('studentFallback')}'.trim();
    final time = _formatTime('${message['createdAt'] ?? ''}');
    final messageId = '${message['id'] ?? ''}';
    final messageKey = _messageKeys.putIfAbsent(messageId, () => GlobalKey());
    return KeyedSubtree(
      key: messageKey,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
        if (!mine) ...[
          InkWell(
            onTap: () => _openStudent(message),
            borderRadius: BorderRadius.circular(22),
            child: CircleAvatar(radius: 17, backgroundColor: scheme.tertiaryContainer, child: Text(_initial(name), style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: _SwipeToReplyBubble(
            mine: mine,
            rtl: Directionality.of(context) == TextDirection.rtl,
            onReply: () => _startReply(message),
            child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 7),
            decoration: BoxDecoration(
              color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: .72),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(16), topEnd: const Radius.circular(16),
                bottomStart: Radius.circular(mine ? 16 : 4), bottomEnd: Radius.circular(mine ? 4 : 16),
              ),
              border: Border.all(color: (mine ? scheme.primary : scheme.outlineVariant).withValues(alpha: .22)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ('${message['replyToMessageId'] ?? ''}'.isNotEmpty) _buildQuotedMessagePreview(context, message),
              InkWell(
                onTap: () => _openStudent(message),
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(name.isEmpty ? l10n.t('studentFallback') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? scheme.onPrimaryContainer : scheme.primary, fontWeight: FontWeight.w800, fontSize: 12))),
                    const SizedBox(width: 8),
                    Text(time, style: TextStyle(color: mine ? scheme.onPrimaryContainer.withValues(alpha: .7) : scheme.onSurfaceVariant, fontSize: 10)),
                  ]),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _showMessageMenu(message, mine: mine),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6, top: 2),
                  child: Text('${message['body'] ?? ''}', style: TextStyle(color: mine ? scheme.onPrimaryContainer : scheme.onSurface, fontSize: 14, height: 1.35)),
                ),
              ),
            ]),
          ),
          ),
        ),
        if (mine) const SizedBox(width: 4),
      ]),
      ),
    );
  }

  Widget _buildReplyComposerPreview(BuildContext context, Map<String, dynamic> target) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final name = '${target['fullName'] ?? target['full_name'] ?? l10n.t('studentFallback')}';
    final body = '${target['body'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 7, bottom: 7),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: .6), borderRadius: BorderRadius.circular(12), border: BorderDirectional(start: BorderSide(color: scheme.primary, width: 3))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l10n.t('replyingTo')} $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary)),
          const SizedBox(height: 2),
          Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ])),
        IconButton(tooltip: l10n.t('cancel'), visualDensity: VisualDensity.compact, onPressed: _cancelReply, icon: const Icon(Icons.close_rounded, size: 18)),
      ]),
    );
  }

  Widget _buildQuotedMessagePreview(BuildContext context, Map<String, dynamic> message) {
    final scheme = Theme.of(context).colorScheme;
    final name = '${message['replyToFullName'] ?? ''}'.trim();
    final body = '${message['replyToBody'] ?? ''}'.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsetsDirectional.only(start: 8, end: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .55), borderRadius: BorderRadius.circular(8), border: BorderDirectional(start: BorderSide(color: scheme.primary, width: 3))),
      child: InkWell(
        onTap: () {
          final targetId = '${message['replyToMessageId'] ?? ''}';
          if (targetId.isNotEmpty) _jumpToMessage(targetId);
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.isEmpty ? AppLocalizations.of(context).t('messageUnavailable') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: scheme.primary)),
        Text(body.isEmpty ? AppLocalizations.of(context).t('messageUnavailable') : body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  String _initial(String name) => name.trim().isEmpty ? '؟' : String.fromCharCode(name.trim().runes.first);

  String _formatTime(String value) {
    final normalized = value.replaceFirst(' ', 'T');
    final date = DateTime.tryParse(normalized)?.toLocal();
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}


/// A chat-native swipe-to-reply interaction. Flutter's horizontal drag
/// recognizer wins only when horizontal movement dominates vertical movement,
/// so ordinary vertical list scrolling remains the natural gesture.
class _SwipeToReplyBubble extends StatefulWidget {
  const _SwipeToReplyBubble({
    required this.mine,
    required this.rtl,
    required this.onReply,
    required this.child,
  });

  final bool mine;
  final bool rtl;
  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReplyBubble> createState() => _SwipeToReplyBubbleState();
}

class _SwipeToReplyBubbleState extends State<_SwipeToReplyBubble> {
  static const double _replyThreshold = 48;
  static const double _maxDrag = 64;
  double _distance = 0;
  bool _dragging = false;

  // Move toward the center of the conversation regardless of locale.
  // The bubble is aligned to Row's start/end, which is direction-aware.
  double get _inwardSign => widget.mine
      ? (widget.rtl ? 1 : -1)
      : (widget.rtl ? -1 : 1);

  void _finishDrag({required bool allowReply}) {
    final shouldReply = allowReply && _distance >= _replyThreshold;
    setState(() {
      _dragging = false;
      _distance = 0;
    });
    if (shouldReply) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => setState(() {
        _dragging = true;
        _distance = 0;
      }),
      onHorizontalDragUpdate: (details) {
        final towardCenter = details.delta.dx * _inwardSign;
        setState(() {
          _distance = (_distance + towardCenter).clamp(0.0, _maxDrag).toDouble();
        });
      },
      onHorizontalDragEnd: (_) => _finishDrag(allowReply: true),
      onHorizontalDragCancel: () => _finishDrag(allowReply: false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _dragging ? _distance : 0),
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        builder: (context, animatedDistance, child) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Align(
                alignment: widget.mine
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Opacity(
                  opacity: (animatedDistance / _replyThreshold).clamp(0.0, 1.0).toDouble(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_inwardSign * animatedDistance, 0),
              child: child,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
