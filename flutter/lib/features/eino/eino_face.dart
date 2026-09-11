import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EinoMood { idle, thinking, talking, happy, error }

/// Lightweight animated Eino face. The painter is intentionally dependency-free
/// so it remains smooth on lower-end phones.
class EinoFace extends StatefulWidget {
  const EinoFace({super.key, this.size = 86, this.talking = false, this.mood = EinoMood.idle});
  final double size;
  final bool talking;
  final EinoMood mood;

  @override
  State<EinoFace> createState() => _EinoFaceState();
}

class _EinoFaceState extends State<EinoFace> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = widget.talking || widget.mood == EinoMood.thinking;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final wave = math.sin(t * (active ? 2.5 : 1));
        final scale = 1 + wave * (active ? .035 : .018);
        final bob = math.sin(t) * (widget.size * .025);
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _EinoFacePainter(primary, widget.mood, widget.talking, _controller.value),
        ),
      ),
    );
  }
}

class _EinoFacePainter extends CustomPainter {
  _EinoFacePainter(this.color, this.mood, this.talking, this.t);
  final Color color;
  final EinoMood mood;
  final bool talking;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * .34;
    final accent = mood == EinoMood.error ? Colors.redAccent : color;

    final glow = Paint()
      ..shader = RadialGradient(colors: [accent.withValues(alpha: .22), accent.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: size.width * .5));
    canvas.drawCircle(c, size.width * .47, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .035
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawCircle(c, r, ring);

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * .018)
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: .28);
    final haloAngle = -math.pi * .25 + t * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.34), haloAngle, math.pi * 1.15, false, halo);

    final eyeY = c.dy - r * .10;
    final eyePaint = Paint()..color = accent;
    final blink = math.sin(t * math.pi * 2 * 1.7).abs() > .965 && mood != EinoMood.talking;
    final eyeHeight = blink ? r * .025 : r * .16;
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - r * .42, eyeY), width: r * .18, height: eyeHeight), eyePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + r * .42, eyeY), width: r * .18, height: eyeHeight), eyePaint);

    final mouth = Path();
    if (mood == EinoMood.error) {
      mouth.moveTo(c.dx - r * .24, c.dy + r * .42);
      mouth.quadraticBezierTo(c.dx, c.dy + r * .25, c.dx + r * .24, c.dy + r * .42);
    } else if (mood == EinoMood.thinking) {
      canvas.drawCircle(Offset(c.dx + r * .16, c.dy + r * .35), r * .045, eyePaint);
      mouth.moveTo(c.dx - r * .22, c.dy + r * .34);
      mouth.quadraticBezierTo(c.dx, c.dy + r * .27, c.dx + r * .18, c.dy + r * .33);
    } else {
      final lift = talking || mood == EinoMood.talking || mood == EinoMood.happy
          ? math.sin(t * math.pi * 2 * 3).abs() * .10 + (mood == EinoMood.happy ? .08 : 0)
          : 0;
      mouth.moveTo(c.dx - r * .25, c.dy + r * .30);
      mouth.quadraticBezierTo(c.dx, c.dy + r * (.43 + lift), c.dx + r * .25, c.dy + r * .30);
    }
    canvas.drawPath(mouth, ring);
  }

  @override
  bool shouldRepaint(covariant _EinoFacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.mood != mood || oldDelegate.talking != talking || oldDelegate.t != t;
}
