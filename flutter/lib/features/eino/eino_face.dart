import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

enum EinoMood { idle, thinking, talking, happy, error }

/// Lightweight animated Eino avatar inspired by the TRINEX character direction.
/// It stays dependency-free for smooth rendering on lower-end phones.
class EinoFace extends StatefulWidget {
  const EinoFace({super.key, this.size = 86, this.talking = false, this.mood = EinoMood.idle});
  final double size;
  final bool talking;
  final EinoMood mood;

  @override
  State<EinoFace> createState() => _EinoFaceState();
}

class _EinoFaceState extends State<EinoFace> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.talking || widget.mood == EinoMood.thinking;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TickerMode(
      enabled: !reduceMotion,
      child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final wave = math.sin(t * (active ? 2.4 : 1));
        final scale = 1 + wave * (active ? .035 : .018);
        final bob = math.sin(t) * (widget.size * .025);
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(painter: _EinoFacePainter(widget.mood, widget.talking, _controller.value)),
            ),
          ),
        );
      },
    ),
    );
  }
}

class _EinoFacePainter extends CustomPainter {
  _EinoFacePainter(this.mood, this.talking, this.t);
  final EinoMood mood;
  final bool talking;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + size.height * .06);
    final r = size.width * .31;
    final orange = mood == EinoMood.error ? AppColors.danger : AppColors.primary;
    const navy = AppColors.navy;

    final glow = Paint()..shader = RadialGradient(colors: [orange.withValues(alpha: .24), orange.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: size.width * .5));
    canvas.drawCircle(c, size.width * .48, glow);

    // Small antenna and ears, echoing the reference character.
    final line = Paint()..color = orange..style = PaintingStyle.stroke..strokeWidth = math.max(2, size.width * .035)..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - r * .38, c.dy - r * 1.02), Offset(c.dx - r * .56, c.dy - r * 1.34), line);
    canvas.drawLine(Offset(c.dx + r * .38, c.dy - r * 1.02), Offset(c.dx + r * .56, c.dy - r * 1.34), line);
    canvas.drawCircle(Offset(c.dx - r * .56, c.dy - r * 1.34), r * .09, Paint()..color = orange);
    canvas.drawCircle(Offset(c.dx + r * .56, c.dy - r * 1.34), r * .09, Paint()..color = orange);

    final head = Paint()..color = navy;
    canvas.drawCircle(c, r, head);
    final rim = Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(2, size.width * .04)..color = orange;
    canvas.drawCircle(c, r, rim);

    final halo = Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.2, size.width * .018)..strokeCap = StrokeCap.round..color = orange.withValues(alpha: .35);
    final haloAngle = -math.pi * .3 + t * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.32), haloAngle, math.pi * .85, false, halo);

    final eyePaint = Paint()..color = orange;
    final blink = math.sin(t * math.pi * 2 * 1.7).abs() > .965 && mood != EinoMood.talking;
    final eyeH = blink ? r * .025 : r * .16;
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - r * .4, c.dy - r * .08), width: r * .19, height: eyeH), eyePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + r * .4, c.dy - r * .08), width: r * .19, height: eyeH), eyePaint);

    final mouth = Path();
    if (mood == EinoMood.error) {
      mouth.moveTo(c.dx - r * .23, c.dy + r * .36);
      mouth.quadraticBezierTo(c.dx, c.dy + r * .19, c.dx + r * .23, c.dy + r * .36);
    } else if (mood == EinoMood.thinking) {
      canvas.drawCircle(Offset(c.dx + r * .18, c.dy + r * .32), r * .045, eyePaint);
      mouth.moveTo(c.dx - r * .2, c.dy + r * .27);
      mouth.quadraticBezierTo(c.dx, c.dy + r * .19, c.dx + r * .18, c.dy + r * .26);
    } else {
      final lift = talking || mood == EinoMood.talking || mood == EinoMood.happy ? math.sin(t * math.pi * 2 * 3).abs() * .08 + (mood == EinoMood.happy ? .08 : 0) : 0;
      mouth.moveTo(c.dx - r * .24, c.dy + r * .24);
      mouth.quadraticBezierTo(c.dx, c.dy + r * (.4 + lift), c.dx + r * .24, c.dy + r * .24);
    }
    canvas.drawPath(mouth, rim);
  }

  @override
  bool shouldRepaint(covariant _EinoFacePainter oldDelegate) => oldDelegate.mood != mood || oldDelegate.talking != talking || oldDelegate.t != t;
}
