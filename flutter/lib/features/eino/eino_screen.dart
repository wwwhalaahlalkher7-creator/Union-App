import 'package:flutter/material.dart';
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
  late EinoRepository _repository;
  ApiClient? _client;
  bool _ready = false;
  bool _sending = false;
  final List<_Message> _messages = [];

  EinoMood get _mood => _sending
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
    _client?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
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

  List<String> _suggestions(AppLocalizations l10n) {
    switch (widget.source) {
      case 'materials':
        return [l10n.t('suggestStudyPlan'), l10n.t('suggestExplainMaterial'), l10n.t('suggestStartFile')];
      case 'schedule':
        return [l10n.t('suggestOrganizeDay'), l10n.t('suggestPrepareClass'), l10n.t('suggestReviewTime')];
      case 'progress':
        return [l10n.t('suggestImproveProgress'), l10n.t('suggestReviewPlan'), l10n.t('suggestKeepGoing')];
      case 'xp':
        return [l10n.t('suggestEarnXp'), l10n.t('suggestProgressMethod'), l10n.t('suggestStudyGoal')];
      case 'badges':
        return [l10n.t('suggestBadges'), l10n.t('suggestNearbyGoal'), l10n.t('suggestKeepProgress')];
      default:
        return [l10n.t('suggestStudy'), l10n.t('suggestDay'), l10n.t('suggestConcept'), l10n.t('suggestApp')];
    }
  }

  String _friendlyError(Object error, AppLocalizations l10n) {
    if (error is ApiException) {
      if (error.message.contains('مزود Eino مشغول')) return l10n.t('einoProviderBusy');
      if (error.message.contains('مزود Eino غير متاح')) return l10n.t('einoProviderUnavailable');
      if (error.message.contains('مسار Eino غير متاح')) return l10n.t('einoProviderRoute');
      if (error.message.contains('التحقق من اتصال Eino')) return l10n.t('einoProviderAuth');
      if (error.message.contains('استغرق Eino')) return l10n.t('einoTimeout');
      if (error.statusCode == 429) return l10n.t('einoRateLimited');
      return error.message;
    }
    return l10n.t('einoGenericError');
  }

  Future<void> _send(BuildContext context, [String? preset]) async {
    if (!_ready || _sending) return;
    final prompt = (preset ?? _controller.text).trim();
    if (prompt.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(true, prompt));
      _sending = true;
    });
    _scrollToBottom();
    await _requestAnswer(prompt);
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
      final history = _messages.length > 10
          ? _messages.sublist(_messages.length - 10, _messages.length)
          : List<_Message>.from(_messages);
      final historyText = history
          .where((m) => !m.isError && m.text != prompt)
          .map((m) => '${m.user ? 'المستخدم' : 'إينو'}: ${m.text}')
          .join('\n');
      final l10n = AppLocalizations.of(context);
      final contextPayload = [
        'صفحة المستخدم الحالية: ${_sourceLabel(l10n)}.',
        if (historyText.isNotEmpty) 'سياق المحادثة السابق:\n$historyText',
      ].join('\n');
      final answer = await _repository.chat(prompt: prompt, context: contextPayload);
      if (mounted) setState(() => _messages.add(_Message(false, answer)));
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _messages.add(_Message(false, _friendlyError(e, l10n), isError: true, retryPrompt: prompt)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const EinoFace(size: 30, mood: _mood),
          const SizedBox(width: 8),
          Text(l10n.t('einoTitle')),
        ]),
        actions: [
          IconButton(
            tooltip: l10n.t('newChat'),
            onPressed: _messages.isEmpty || _sending ? null : () => setState(() => _messages.clear()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _welcome(cs, l10n)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) return _typingBubble(cs);
                      final message = _messages[i];
                      return _AnimatedEntry(
                        key: ValueKey('${message.text}-$i'),
                        child: _bubble(context, message),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _composer(cs, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcome(ColorScheme cs, AppLocalizations l10n) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          Center(child: EinoFace(size: 128, mood: _mood)),
          const SizedBox(height: 8),
          Center(child: Text(l10n.t('einoGreeting'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          Center(child: Text(l10n.t('withYou', {'section': _sourceLabel(l10n)}), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          Text(l10n.t('einoWelcome'), textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 22),
          Text(l10n.t('suggestions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 9, runSpacing: 9, children: _suggestions(l10n).map((text) => _prompt(text, cs)).toList()),
        ],
      );

  Widget _prompt(String text, ColorScheme cs) => ActionChip(
        label: Text(text),
        onPressed: _sending ? null : () => _send(context, text),
        side: BorderSide.none,
        backgroundColor: cs.surfaceContainerHighest,
      );

  Widget _bubble(BuildContext context, _Message m) {
    final cs = Theme.of(context).colorScheme;
    if (m.isError) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 10),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: const Radius.circular(5)),
            border: Border.all(color: cs.error.withValues(alpha: .18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const EinoFace(size: 34, mood: EinoMood.error),
              const SizedBox(width: 9),
              Expanded(child: Text(m.text, style: TextStyle(color: cs.onErrorContainer, height: 1.45))),
            ]),
            const SizedBox(height: 5),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _sending ? null : () => _retry(m.retryPrompt ?? ''),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppLocalizations.of(context).t('einoRetry')),
              ),
            ),
          ]),
        ),
      );
    }
    return Align(
      alignment: m.user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: m.user ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: m.user ? const Radius.circular(5) : null,
            bottomLeft: !m.user ? const Radius.circular(5) : null,
          ),
        ),
        child: m.user
            ? Text(m.text, style: TextStyle(color: cs.onPrimary, height: 1.45))
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const EinoFace(size: 32, mood: EinoMood.happy),
                const SizedBox(width: 9),
                Expanded(child: SelectableText(m.text, style: const TextStyle(height: 1.5))),
              ]),
      ),
    );
  }

  Widget _typingBubble(ColorScheme cs) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: const Radius.circular(5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const EinoFace(size: 30, mood: EinoMood.thinking),
            const SizedBox(width: 9),
            _TypingDots(color: cs.onSurfaceVariant),
          ]),
        ),
      );

  Widget _composer(ColorScheme cs, AppLocalizations l10n) => Container(
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: l10n.t('einoHint'), fillColor: Colors.transparent),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: _sending ? null : () => _send(context),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: _sending
                  ? const SizedBox(key: ValueKey('loading'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_upward_rounded, key: ValueKey('send')),
            ),
          ),
        ]),
      );
}

class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({required this.child, super.key});
  final Widget child;
  @override State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return AnimatedBuilder(animation: curved, builder: (context, child) => Opacity(opacity: curved.value, child: Transform.translate(offset: Offset(0, (1 - curved.value) * 12), child: child)), child: widget.child);
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});
  final Color color;
  @override State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          final phase = (_controller.value - i * .18) % 1.0;
          final lift = phase < .5 ? phase * 2 : (1 - phase) * 2;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.translate(offset: Offset(0, -lift * 4), child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: .6 + lift * .4)))),
          );
        })),
      );
}

class _Message {
  const _Message(this.user, this.text, {this.isError = false, this.retryPrompt});
  final bool user;
  final String text;
  final bool isError;
  final String? retryPrompt;
}
