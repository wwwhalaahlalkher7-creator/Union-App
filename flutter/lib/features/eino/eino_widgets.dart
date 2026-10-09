import 'package:latext/latext.dart';
import 'package:flutter/material.dart';

class EinoAnimatedEntry extends StatefulWidget {
  const EinoAnimatedEntry({required this.child, super.key});
  final Widget child;
  @override State<EinoAnimatedEntry> createState() => _EinoAnimatedEntryState();
}

class _EinoAnimatedEntryState extends State<EinoAnimatedEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 260),
  )..forward();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, (1 - curved.value) * 12), child: child),
      ),
      child: widget.child,
    );
  }
}

class EinoTypingDots extends StatefulWidget {
  const EinoTypingDots({super.key, required this.color});
  final Color color;
  @override State<EinoTypingDots> createState() => _EinoTypingDotsState();
}

class _EinoTypingDotsState extends State<EinoTypingDots> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900),
  )..repeat();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i / 3) % 1.0;
            final opacity = 0.25 + (0.75 * (0.5 + 0.5 * (1 - (phase - 0.5).abs() * 2)));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(opacity: opacity, child: Icon(Icons.circle, size: 5, color: widget.color)),
            );
          }),
        );
      },
    );
  }
}


/// Markdown + TeX renderer for Eino messages. It deliberately renders formatting
/// rather than exposing Markdown markers to the user.
class EinoMathText extends StatelessWidget {
  const EinoMathText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final lines = _prepareMathLines(text.replaceAll('\r\n', '\n'));
    final widgets = <Widget>[];
    var inCode = false;
    final code = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          widgets.add(Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: base.color?.withValues(alpha: .07), borderRadius: BorderRadius.circular(8)), child: SelectableText(code.join('\n'), style: base.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 14) * .92))));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) { code.add(line); continue; }
      final trimmed = line.trim();
      if (trimmed.isEmpty) { widgets.add(const SizedBox(height: 5)); continue; }
      final displayMath = RegExp(r'^\$\$([\s\S]*?)\$\$$').firstMatch(trimmed) ?? RegExp(r'^\\\[([\s\S]*?)\\\]$').firstMatch(trimmed) ?? (RegExp(r'\\(?:sqrt|frac|sum|int|times|cdot|Longleftrightarrow)|\^[{]').hasMatch(trimmed) ? RegExp(r'^(.*)$').firstMatch(trimmed) : null);
      if (displayMath != null) {
        widgets.add(Container(width: double.infinity, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 7), child: LaTexT(laTeXCode: Text('\$\$${displayMath.group(1)}\$\$', style: base))));
        continue;
      }
      if (RegExp(r'^\s*([-*_]\s*){3,}$').hasMatch(line)) { widgets.add(const Divider(height: 14)); continue; }
      var content = trimmed;
      var prefix = '';
      var lineStyle = base;
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(content);
      if (heading != null) {
        final level = heading.group(1)!.length;
        content = heading.group(2)!;
        lineStyle = base.copyWith(fontSize: (base.fontSize ?? 14) + (7 - level) * 1.5, fontWeight: FontWeight.w800);
      } else {
        final bullet = RegExp(r'^(\s*)([-*+]\s+|\d+[.)]\s+|>\s+)(.*)$').firstMatch(line);
        if (bullet != null) {
          final marker = bullet.group(2)!;
          prefix = marker.startsWith('>') ? '▏ ' : (RegExp(r'^\d').hasMatch(marker) ? '${marker.trim()} ' : '• ');
          content = bullet.group(3)!;
          if (marker.startsWith('>')) lineStyle = base.copyWith(fontStyle: FontStyle.italic, color: base.color?.withValues(alpha: .85));
        }
      }
      widgets.add(_inline(content, lineStyle, prefix: prefix));
    }
    if (code.isNotEmpty) widgets.add(SelectableText(code.join('\n'), style: base.copyWith(fontFamily: 'monospace')));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: widgets);
  }

  List<String> _prepareMathLines(String input) {
    final source = input.split('\n');
    final out = <String>[];
    final buffer = <String>[];
    String? closing;
    for (final line in source) {
      final t = line.trim();
      if (closing != null) {
        if (t.contains(closing)) {
          buffer.add(t.substring(0, t.indexOf(closing)));
          out.add(r'\[' + buffer.join(' ') + r'\]');
          final tail = t.substring(t.indexOf(closing) + closing.length).trim();
          if (tail.isNotEmpty) out.add(tail);
          buffer.clear(); closing = null;
        } else { buffer.add(t); }
        continue;
      }
      if (t == r'\[' || t == r'\(') { closing = t == r'\[' ? r'\]' : r'\)'; buffer.clear(); continue; }
      if (t == r'\]' || t == r'\)' || t == ']\\' || t == ')\\' || t == '[\\' || t == '(\\') continue;
      out.add(line);
    }
    if (buffer.isNotEmpty) out.add(buffer.join(' '));
    return out;
  }

  Widget _inline(String input, TextStyle base, {String prefix = ''}) {
    final parts = <Widget>[];
    if (prefix.isNotEmpty) parts.add(Text(prefix, style: base.copyWith(fontWeight: FontWeight.w700)));
    final math = RegExp(r'\$([^$\n]+)\$|\\\((.*?)\\\)');
    var cursor = 0;
    for (final match in math.allMatches(input)) {
      if (match.start > cursor) parts.add(RichText(text: _markdownSpans(input.substring(cursor, match.start), base))); 
      final formula = match.group(1) ?? match.group(2) ?? '';
      parts.add(LaTexT(laTeXCode: Text('\$$formula\$', style: base)));
      cursor = match.end;
    }
    if (cursor < input.length) parts.add(RichText(text: _markdownSpans(input.substring(cursor), base))); 
    if (parts.isEmpty) parts.add(Text('', style: base));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 2, children: parts));
  }

  TextSpan _markdownSpans(String value, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|~~(.+?)~~|`([^`]+)`');
    var cursor = 0;
    for (final m in pattern.allMatches(value)) {
      if (m.start > cursor) spans.add(TextSpan(text: value.substring(cursor, m.start)));
      final strong = m.group(1) ?? m.group(2);
      final italic = m.group(3) ?? m.group(4);
      final strike = m.group(5);
      final inlineCode = m.group(6);
      final childStyle = strong != null ? base.copyWith(fontWeight: FontWeight.w800) : italic != null ? base.copyWith(fontStyle: FontStyle.italic) : strike != null ? base.copyWith(decoration: TextDecoration.lineThrough) : base.copyWith(fontFamily: 'monospace', backgroundColor: base.color?.withValues(alpha: .08));
      spans.add(TextSpan(text: strong ?? italic ?? strike ?? inlineCode, style: childStyle));
      cursor = m.end;
    }
    if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));
    return TextSpan(children: spans, style: base);
  }
}

/// Plain-text version used for copy and speech; strips presentation syntax,
/// while preserving the readable contents of equations and code.
String einoPlainText(String input, {bool forSpeech = false}) {
  var value = input.replaceAllMapped(RegExp(r'```[^\n]*\n([\s\S]*?)```'), (m) => m.group(1) ?? ' ');
  value = value.replaceAllMapped(RegExp(r'\\\[([\s\S]*?)\\\]|\\\(([\s\S]*?)\\\)|\$\$([\s\S]*?)\$\$|\$([^$\n]+)\$'), (m) => ' ${m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? ''} ');
  value = value.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
  value = value.replaceAll(RegExp(r'^\s*([-*+]\s+|\d+[.)]\s+|>\s+)', multiLine: true), '');
  value = value.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*|__(.*?)__|\*(.*?)\*|_(.*?)_|~~(.*?)~~|`([^`]+)`'), (m) => m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? m.group(5) ?? m.group(6) ?? '');
  value = value.replaceAllMapped(RegExp(r'\\(?:text|mathrm|mathbf|operatorname)\{([^{}]*)\}'), (m) => m.group(1) ?? '');
  if (forSpeech) {
    value = value.replaceAll(RegExp(r'\\(?:left|right|displaystyle|quad|qquad)'), ' ')
      .replaceAll(r'\times', ' في ').replaceAll(r'\cdot', ' في ').replaceAll(r'\div', ' على ')
      .replaceAll(r'\pm', ' زائد أو ناقص ').replaceAll(r'\leq', ' أقل من أو يساوي ').replaceAll(r'\geq', ' أكبر من أو يساوي ')
      .replaceAll(r'\neq', ' لا يساوي ').replaceAll(r'\approx', ' تقريبًا ').replaceAll(r'\sqrt', ' الجذر التربيعي ')
      .replaceAll(r'\pi', ' باي ').replaceAll(r'\infty', ' ما لا نهاية ').replaceAll(r'\sum', ' مجموع ')
      .replaceAll(r'\int', ' تكامل ').replaceAll(r'\frac', ' كسر ')
      .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ')
      .replaceAll(RegExp(r'[{}$*_#`~\\]'), ' ')
      .replaceAll('=', ' يساوي ').replaceAll('+', ' زائد ').replaceAll('−', ' ناقص ').replaceAll('-', ' ناقص ')
      .replaceAll('*', ' في ').replaceAll('/', ' على ');
  }
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class EinoMessage {
  const EinoMessage(this.user, this.text, {this.isError = false, this.retryPrompt, this.sourceTitle, this.imageBase64, this.imageContentType});
  final bool user;
  final String text;
  final bool isError;
  final String? retryPrompt;
  final String? sourceTitle;
  final String? imageBase64;
  final String? imageContentType;
}


