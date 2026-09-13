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
      : _messages.isEmpty
          ? EinoMood.idle
          : EinoMood.happy;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final client = await AuthenticatedClient.create();
    _client = client;
    _repository = EinoRepository(client);
    if (mounted) setState(() => _ready = true);
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

  String get _sourceLabel {
    switch (widget.source) {
      case 'materials': return 'المواد الدراسية';
      case 'schedule': return 'الجدول';
      case 'progress': return 'التقدم الدراسي';
      case 'xp': return 'نقاط XP';
      case 'badges': return 'الشارات';
      case 'student': return 'حساب الطالب';
      default: return 'الرئيسية';
    }
  }

  List<String> get _suggestions {
    switch (widget.source) {
      case 'materials':
        return ['ساعديني أرتب مذاكرتي', 'اشرحي لي مفهوم من المادة', 'كيف أبدأ بهذا الملف؟'];
      case 'schedule':
        return ['رتبي لي يومي الدراسي', 'كيف أستعد للحصة القادمة؟', 'اقترحي لي وقتًا للمراجعة'];
      case 'progress':
        return ['كيف أحسن تقدمي؟', 'ساعديني بخطة مراجعة', 'كيف أستمر بدون ضغط؟'];
      case 'xp':
        return ['كيف أكسب XP من الدراسة؟', 'ما أفضل طريقة للتقدم؟', 'ساعديني أضع هدفًا دراسيًا'];
      case 'badges':
        return ['كيف أحقق الشارات؟', 'اقترحي لي هدفًا قريبًا', 'كيف أحافظ على تقدمي؟'];
      default:
        return ['📚 ساعديني في الدراسة', '🗓️ ساعديني في يومي', '💡 اشرحي لي مفهومًا', '🔎 ساعديني في التطبيق'];
    }
  }

  Future<void> _send([String? preset]) async {
    if (!_ready || _sending) return;
    final prompt = (preset ?? _controller.text).trim();
    if (prompt.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(true, prompt));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final history = _messages.length > 10
          ? _messages.sublist(_messages.length - 10, _messages.length - 1)
          : _messages.sublist(0, _messages.length - 1);
      final historyText = history.map((m) => '${m.user ? 'المستخدم' : 'إينو'}: ${m.text}').join('\n');
      final context = [
        'صفحة المستخدم الحالية: $_sourceLabel.',
        if (historyText.isNotEmpty) 'سياق المحادثة السابق:\n$historyText',
      ].join('\n');
      final answer = await _repository.chat(prompt: prompt, context: context);
      if (mounted) setState(() => _messages.add(_Message(false, answer)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(_Message(false, e.toString().replaceFirst('ApiException(null): ', ''))));
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
        title: const Text('إينو'),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
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
                      return _AnimatedEntry(key: ValueKey(i), child: _bubble(context, _messages[i]));
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
          const Center(child: Text('أنا إينو ✨', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'موجودة معك في $_sourceLabel',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.t('einoWelcome'), textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 22),
          Text('اقتراحات مناسبة لك', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _suggestions.map((text) => _prompt(text, cs)).toList(),
          ),
        ],
      );

  Widget _prompt(String text, ColorScheme cs) => ActionChip(
        label: Text(text),
        onPressed: _sending ? null : () => _send(text),
        side: BorderSide.none,
        backgroundColor: cs.surfaceContainerHighest,
      );

  Widget _bubble(BuildContext context, _Message m) {
    final cs = Theme.of(context).colorScheme;
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
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EinoFace(size: 32, mood: EinoMood.happy),
                  const SizedBox(width: 9),
                  Expanded(child: SelectableText(m.text, style: const TextStyle(height: 1.5))),
                ],
              ),
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
            const EinoFace(size: 30, talking: true, mood: EinoMood.thinking),
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
            onPressed: _sending ? null : () => _send(),
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
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * .18) % 1.0;
            final lift = phase < .5 ? phase * 2 : (1 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -lift * 4),
                child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: .6 + lift * .4))),
              ),
            );
          }),
        ),
      );
}

class _Message {
  const _Message(this.user, this.text);
  final bool user;
  final String text;
}
