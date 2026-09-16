import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/repositories/eino_repository.dart';
import 'eino_face.dart';

class EinoScreen extends StatefulWidget {
  const EinoScreen({super.key, this.source = 'home'});
  final String source;

  @override
  State<EinoScreen> createState() => _EinoScreenState();
}

class _EinoScreenState extends State<EinoScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  late EinoRepository _repository;
  ApiClient? _client;
  bool _ready = false;
  bool _sending = false;
  bool _recording = false;
  bool _uploading = false;
  final List<_Message> _messages = [];
  final List<_ChatPreview> _history = [];

  EinoMood get _mood => _recording || _sending || _uploading
      ? EinoMood.thinking
      : _messages.any((m) => !m.user && !m.isError)
          ? EinoMood.happy
          : EinoMood.idle;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final client = await AuthenticatedClient.create();
    if (!mounted) {
      client.dispose();
      return;
    }
    _client = client;
    _repository = EinoRepository(client);
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _player.dispose();
    _client?.dispose();
    super.dispose();
  }

  String _sourceLabel(AppLocalizations l10n) {
    switch (widget.source) {
      case 'materials': return l10n.t('sourceMaterials');
      case 'schedule': return l10n.t('sourceSchedule');
      case 'progress': return l10n.t('sourceProgress');
      case 'xp': return l10n.t('sourceXp');
      case 'badges': return l10n.t('sourceBadges');
      case 'student': return l10n.t('sourceStudent');
      default: return l10n.t('sourceHome');
    }
  }

  List<String> _suggestions(AppLocalizations l10n) => switch (widget.source) {
        'materials' => [l10n.t('suggestStudyPlan'), l10n.t('suggestExplainMaterial'), l10n.t('suggestStartFile')],
        'schedule' => [l10n.t('suggestOrganizeDay'), l10n.t('suggestPrepareClass'), l10n.t('suggestReviewTime')],
        'progress' => [l10n.t('suggestImproveProgress'), l10n.t('suggestReviewPlan'), l10n.t('suggestKeepGoing')],
        'xp' => [l10n.t('suggestEarnXp'), l10n.t('suggestProgressMethod'), l10n.t('suggestStudyGoal')],
        'badges' => [l10n.t('suggestBadges'), l10n.t('suggestNearbyGoal'), l10n.t('suggestKeepProgress')],
        _ => [l10n.t('suggestStudy'), l10n.t('suggestDay'), l10n.t('suggestConcept'), l10n.t('suggestApp')],
      };

  String _friendlyError(Object error, AppLocalizations l10n) {
    if (error is ApiException) {
      if (error.statusCode == 429) return l10n.t('einoRateLimited');
      if (error.message.contains('مزود Eino مشغول')) return l10n.t('einoProviderBusy');
      if (error.message.contains('مزود Eino غير متاح')) return l10n.t('einoProviderUnavailable');
      if (error.message.contains('استغرق Eino')) return l10n.t('einoTimeout');
      return error.message;
    }
    return l10n.t('einoGenericError');
  }

  Future<void> _send([String? preset]) async {
    if (!_ready || _sending || _uploading) return;
    final prompt = (preset ?? _controller.text).trim();
    if (prompt.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(true, prompt));
      _sending = true;
    });
    _rememberChat(prompt);
    _scrollToBottom();
    await _requestAnswer(prompt);
  }

  void _rememberChat(String prompt) {
    final title = prompt.length > 34 ? '${prompt.substring(0, 34)}…' : prompt;
    _history.removeWhere((x) => x.title == title);
    _history.insert(0, _ChatPreview(title, DateTime.now()));
    if (_history.length > 12) _history.removeLast();
  }

  Future<void> _retry(String prompt) async {
    if (!_ready || _sending || prompt.trim().isEmpty) return;
    setState(() {
      final index = _messages.lastIndexWhere((m) => m.isError && m.retryPrompt == prompt);
      if (index >= 0) _messages.removeAt(index);
      _sending = true;
    });
    await _requestAnswer(prompt);
  }

  Future<void> _requestAnswer(String prompt) async {
    try {
      final history = _messages.length > 10 ? _messages.sublist(_messages.length - 10) : List<_Message>.from(_messages);
      final historyText = history.where((m) => !m.isError && m.text != prompt).map((m) => '${m.user ? 'المستخدم' : 'إينو'}: ${m.text}').join('\n');
      final l10n = AppLocalizations.of(context);
      final contextPayload = ['صفحة المستخدم الحالية: ${_sourceLabel(l10n)}.', if (historyText.isNotEmpty) 'سياق المحادثة السابق:\n$historyText'].join('\n');
      final answer = await _repository.chat(prompt: prompt, context: contextPayload);
      if (mounted) setState(() => _messages.add(_Message(false, answer)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(_Message(false, _friendlyError(e, AppLocalizations.of(context)), isError: true, retryPrompt: prompt)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _pickMedia() async {
    if (_sending || _uploading) return;
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.image_outlined), title: Text(l10n.t('einoAttachImage')), subtitle: Text(l10n.t('einoVisionSubtitle')), onTap: () => Navigator.pop(context, 'image')),
          ListTile(leading: const Icon(Icons.description_outlined), title: Text(l10n.t('einoAttachDocument')), subtitle: Text(l10n.t('einoDocumentSubtitle')), onTap: () => Navigator.pop(context, 'document')),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    final result = await FilePicker.platform.pickFiles(withData: true, type: choice == 'image' ? FileType.image : FileType.custom, allowedExtensions: choice == 'document' ? ['pdf', 'docx', 'txt'] : null);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final name = file.name;
      if (choice == 'image') {
        final mime = _mime(name);
        final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        final text = await _repository.vision(imageDataUrl: dataUrl);
        if (mounted) {
          setState(() {
          _messages.add(_Message(true, '🖼️ $name'));
          _messages.add(_Message(false, text));
          });
        }
      } else {
        final text = await _repository.ocr(bytes: bytes, filename: name, contentType: _mime(name));
        if (mounted) {
          setState(() {
          _messages.add(_Message(true, '📄 $name'));
          _messages.add(_Message(false, text));
          });
        }
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _messages.add(_Message(false, _friendlyError(e, l10n), isError: true)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mime(String name) {
    switch (name.toLowerCase().split('.').last) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'pdf': return 'application/pdf';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt': return 'text/plain';
      case 'm4a': return 'audio/mp4';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _toggleRecording() async {
    if (_sending || _uploading) return;
    if (_recording) {
      final path = await _recorder.stop();
      if (mounted) setState(() => _recording = false);
      if (path == null) return;
      setState(() => _uploading = true);
      try {
        final file = File(path);
        final text = await _repository.stt(bytes: await file.readAsBytes(), filename: 'eino_recording.m4a', contentType: 'audio/mp4');
        if (text.trim().isNotEmpty) {
          _controller.text = text.trim();
          _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        }
      } catch (e) {
        if (mounted) setState(() => _messages.add(_Message(false, _friendlyError(e, AppLocalizations.of(context)), isError: true)));
      } finally {
        if (mounted) setState(() => _uploading = false);
        try { await File(path).delete(); } catch (_) {}
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('einoMicPermission'))));
      return;
    }
    final path = '${Directory.systemTemp.path}/eino_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _speak(_Message message) async {
    if (message.user || message.text.trim().isEmpty) return;
    try {
      final url = await _repository.tts(text: message.text);
      if (url == null || url.isEmpty) return;
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e, AppLocalizations.of(context)))));
    }
  }

  void _newChat() {
    if (_sending || _uploading) return;
    setState(() => _messages.clear());
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      drawer: _drawer(cs, l10n),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu_rounded), tooltip: l10n.t('einoHistory'), onPressed: () => Scaffold.of(context).openDrawer())),
        titleSpacing: 4,
        title: Row(children: [EinoFace(size: 32, mood: _mood), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.t('einoTitle'), style: const TextStyle(fontWeight: FontWeight.w800)), Text(l10n.t('einoOnline'), style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700))])]),
        actions: [IconButton(tooltip: l10n.t('newChat'), onPressed: _messages.isEmpty || _sending || _uploading ? null : _newChat, icon: const Icon(Icons.edit_square)), const SizedBox(width: 4)],
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty ? _welcome(cs, l10n) : ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), itemCount: _messages.length + (_sending || _uploading ? 1 : 0), itemBuilder: (_, i) {
          if (i == _messages.length) return _typingBubble(cs, uploading: _uploading);
          final message = _messages[i];
          return _AnimatedEntry(key: ValueKey('${message.text}-$i'), child: _bubble(context, message));
        })),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10), child: _composer(cs, l10n))),
      ]),
    );
  }

  Widget _drawer(ColorScheme cs, AppLocalizations l10n) => Drawer(child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 12), child: Row(children: [EinoFace(size: 48, mood: EinoMood.happy), const SizedBox(width: 12), Expanded(child: Text(l10n.t('einoHistory'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: FilledButton.icon(onPressed: _newChat, icon: const Icon(Icons.add_rounded), label: Text(l10n.t('newChat')))),
    const SizedBox(height: 12),
    if (_history.isEmpty) Expanded(child: Center(child: Text(l10n.t('einoNoHistory'), style: TextStyle(color: cs.onSurfaceVariant))))
    else Expanded(child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: _history.length, separatorBuilder: (_, _) => const SizedBox(height: 2), itemBuilder: (_, i) => ListTile(leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20), title: Text(_history[i].title, maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => Navigator.pop(context)))),
  ])));

  Widget _welcome(ColorScheme cs, AppLocalizations l10n) => ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 20), children: [
    Center(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: .45), shape: BoxShape.circle), child: EinoFace(size: 116, mood: _mood))),
    const SizedBox(height: 14),
    Center(child: Text(l10n.t('einoGreeting'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
    const SizedBox(height: 6),
    Center(child: Text(l10n.t('withYou', {'section': _sourceLabel(l10n)}), textAlign: TextAlign.center, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700))),
    const SizedBox(height: 10),
    Text(l10n.t('einoWelcome'), textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
    const SizedBox(height: 24),
    Wrap(spacing: 9, runSpacing: 9, children: _suggestions(l10n).map((text) => ActionChip(label: Text(text), onPressed: _sending ? null : () => _send(text), side: BorderSide(color: cs.outlineVariant.withValues(alpha: .5)), backgroundColor: cs.surfaceContainerHighest)).toList()),
  ]);

  Widget _bubble(BuildContext context, _Message m) {
    final cs = Theme.of(context).colorScheme;

    if (m.isError) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 9),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft: const Radius.circular(5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EinoFace(size: 34, mood: EinoMood.error),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      m.text,
                      style: TextStyle(color: cs.onErrorContainer, height: 1.45),
                    ),
                  ),
                ],
              ),
              if (m.retryPrompt != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _sending ? null : () => _retry(m.retryPrompt!),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(AppLocalizations.of(context).t('einoRetry')),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: m.user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: m.user ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: m.user ? const Radius.circular(5) : null,
            bottomLeft: !m.user ? const Radius.circular(5) : null,
          ),
        ),
        child: m.user
            ? Text(
                m.text,
                style: TextStyle(color: cs.onPrimary, height: 1.5),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EinoFace(size: 31, mood: EinoMood.happy),
                      const SizedBox(width: 9),
                      Expanded(
                        child: SelectableText(
                          m.text,
                          style: const TextStyle(height: 1.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      onPressed: () => _speak(m),
                      tooltip: AppLocalizations.of(context).t('einoListen'),
                      icon: const Icon(Icons.volume_up_outlined, size: 19),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _typingBubble(ColorScheme cs, {required bool uploading}) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: const Radius.circular(5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EinoFace(size: 30, mood: EinoMood.thinking),
            const SizedBox(width: 9),
            uploading
                ? Text(
                    AppLocalizations.of(context).t('einoProcessing'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                : _TypingDots(color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _composer(ColorScheme cs, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .4)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: l10n.t('einoAttach'),
            onPressed: _sending || _uploading ? null : _pickMedia,
            icon: const Icon(Icons.add_rounded),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.t('einoHint'),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 11,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _recording
                ? l10n.t('einoStopRecording')
                : l10n.t('einoVoice'),
            onPressed: _sending || _uploading ? null : _toggleRecording,
            color: _recording ? cs.error : null,
            icon: Icon(
              _recording
                  ? Icons.stop_circle_outlined
                  : Icons.mic_none_rounded,
            ),
          ),
          const SizedBox(width: 2),
          IconButton.filled(
            tooltip: l10n.t('send'),
            onPressed: _sending || _uploading ? null : () => _send(),
            icon: _sending
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }

}

class _AnimatedEntry extends StatefulWidget { const _AnimatedEntry({required this.child, super.key}); final Widget child; @override State<_AnimatedEntry> createState() => _AnimatedEntryState(); }
class _AnimatedEntryState extends State<_AnimatedEntry> with SingleTickerProviderStateMixin { late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward(); @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic); return AnimatedBuilder(animation: curved, builder: (context, child) => Opacity(opacity: curved.value, child: Transform.translate(offset: Offset(0, (1 - curved.value) * 12), child: child)), child: widget.child); } }
class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});
  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * .18) % 1.0;
            final lift = phase < .5 ? phase * 2 : (1 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -lift * 4),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: .6 + lift * .4),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Message { const _Message(this.user, this.text, {this.isError = false, this.retryPrompt}); final bool user; final String text; final bool isError; final String? retryPrompt; }
class _ChatPreview { const _ChatPreview(this.title, this.date); final String title; final DateTime date; }
