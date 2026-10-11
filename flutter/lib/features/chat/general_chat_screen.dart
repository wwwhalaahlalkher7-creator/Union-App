import 'dart:async';

import 'package:flutter/material.dart';
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
  Timer? _pollTimer;
  String? _studentId;
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  String? _loadError;

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
      final message = await _repository.send(text);
      if (!mounted) return;
      _composer.clear();
      setState(() {
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
    final id = '${message['studentId'] ?? ''}'.trim();
    if (id.isEmpty) return;
    context.push('/student/profile/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent('${message['fullName'] ?? ''}')}&department=${Uri.encodeQueryComponent('${message['departmentName'] ?? ''}')}&semester=${Uri.encodeQueryComponent('${message['semesterName'] ?? ''}')}');
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
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _messageBubble(context, _messages[index]),
      ),
    );
  }

  Widget _messageBubble(BuildContext context, Map<String, dynamic> message) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mine = '${message['studentId'] ?? ''}' == _studentId;
    final name = '${message['fullName'] ?? l10n.t('studentFallback')}'.trim();
    final time = _formatTime('${message['createdAt'] ?? ''}');
    return Padding(
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
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 7),
            decoration: BoxDecoration(
              color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: .72),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: Border.all(color: (mine ? scheme.primary : scheme.outlineVariant).withValues(alpha: .22)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: InkWell(onTap: () => _openStudent(message), child: Text(mine ? l10n.t('chatYou') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? scheme.onPrimaryContainer : scheme.primary, fontWeight: FontWeight.w800, fontSize: 12)))),
                const SizedBox(width: 8),
                Text(time, style: TextStyle(color: mine ? scheme.onPrimaryContainer.withValues(alpha: .7) : scheme.onSurfaceVariant, fontSize: 10)),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                  iconSize: 17,
                  tooltip: l10n.t('chatMessageOptions'),
                  onSelected: (value) => value == 'delete' ? _deleteMessage(message) : _reportMessage(message),
                  itemBuilder: (_) => [
                    if (mine) PopupMenuItem(value: 'delete', child: Text(l10n.t('delete'))),
                    if (!mine) PopupMenuItem(value: 'report', child: Text(l10n.t('chatReport'))),
                  ],
                ),
              ]),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6, top: 2),
                child: SelectableText('${message['body'] ?? ''}', style: TextStyle(color: mine ? scheme.onPrimaryContainer : scheme.onSurface, fontSize: 14, height: 1.35)),
              ),
            ]),
          ),
        ),
        if (mine) const SizedBox(width: 4),
      ]),
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
