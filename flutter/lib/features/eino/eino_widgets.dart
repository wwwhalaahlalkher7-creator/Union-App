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


/// Renders Eino's mathematical notation using a real TeX renderer instead of
/// showing LaTeX source as ordinary text. We normalize the delimiters emitted
/// by different providers to the delimiters supported consistently by LaTexT.
class EinoMathText extends StatelessWidget {
  const EinoMathText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  String _normalize(String value) {
    var result = value
        .replaceAllMapped(RegExp(r'\\\[([\s\S]*?)\\\]'), (m) => '\$\$${m.group(1)}\$\$')
        .replaceAllMapped(RegExp(r'\\\(([\s\S]*?)\\\)'), (m) => '\$${m.group(1)}\$');
    // Some providers emit Unicode minus or non-breaking spaces inside math.
    result = result.replaceAll('\u2212', '-').replaceAll('\u00a0', ' ');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalize(text);
    final effective = style ?? DefaultTextStyle.of(context).style;
    return LaTexT(
      laTeXCode: Text(normalized, style: effective.copyWith(height: effective.height ?? 1.55)),
    );
  }
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


