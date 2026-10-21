import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Visual state for Eino's glass-light core.
/// Legacy mood names remain available so existing screens stay compatible.
enum EinoMood {
  calm,
  happy,
  curious,
  focused,
  surprised,
  confused,
  pouting,
  concerned,
  proud,
  thinking,
  talking;

  static const EinoMood idle = EinoMood.calm;
  static const EinoMood error = EinoMood.concerned;
}

/// Eino's animated, organic/technical glass orb.
/// Kept under the historical EinoFace name to avoid breaking existing callers.
class EinoFace extends StatefulWidget {
  const EinoFace({
    super.key,
    this.size = 86,
    this.talking = false,
    this.mood = EinoMood.calm,
    this.accentColor,
    this.showAura = true,
  });

  final double size;
  final bool talking;
  final EinoMood mood;
  final Color? accentColor;
  final bool showAura;

  @override
  State<EinoFace> createState() => _EinoFaceState();
}

/// New semantic name for use in new code.
typedef EinoOrb = EinoFace;

class _EinoFaceState extends State<EinoFace> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isActive = widget.talking ||
        widget.mood == EinoMood.thinking ||
        widget.mood == EinoMood.talking;
    final label = switch (widget.mood) {
      EinoMood.concerned => 'Eino connection issue',
      EinoMood.thinking || EinoMood.focused => 'Eino thinking',
      EinoMood.talking => 'Eino responding',
      _ when widget.talking => 'Eino listening or speaking',
      _ => 'Eino assistant',
    };

    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = reduceMotion ? 0.28 : _controller.value;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _EinoOrbPainter(
                  time: t,
                  mood: widget.mood,
                  talking: widget.talking,
                  accent: widget.accentColor ?? const Color(0xFF4A7BFF),
                  showAura: widget.showAura,
                  active: isActive,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EinoOrbPainter extends CustomPainter {
  const _EinoOrbPainter({
    required this.time,
    required this.mood,
    required this.talking,
    required this.accent,
    required this.showAura,
    required this.active,
  });

  final double time;
  final EinoMood mood;
  final bool talking;
  final Color accent;
  final bool showAura;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    if (shortest <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortest * 0.355;
    final phase = time * math.pi * 2;
    final isError = mood == EinoMood.concerned;
    final isThinking = mood == EinoMood.thinking || mood == EinoMood.focused;
    final isSpeaking = talking || mood == EinoMood.talking;
    final blue = isError ? const Color(0xFFFF6B72) : accent;
    const violet = Color(0xFF965CFF);
    const pink = Color(0xFFFF8FCF);
    const gold = Color(0xFFFFC875);

    // Soft ambient light, intentionally subtle at small floating-button sizes.
    if (showAura) {
      final aura = Paint()
        ..shader = RadialGradient(
          colors: [blue.withValues(alpha: active ? .34 : .20), violet.withValues(alpha: .08), Colors.transparent],
          stops: const [0, .48, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.9));
      canvas.drawCircle(center, radius * 1.9, aura);
    }

    // Outer glass shell.
    final shellRect = Rect.fromCircle(center: center, radius: radius);
    final shell = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.38, -.48),
        radius: 1.15,
        colors: [Color(0xFF315B9A), Color(0xFF111E3D), Color(0xFF070E20)],
        stops: [0, .48, 1],
      ).createShader(shellRect);
    canvas.drawCircle(center, radius, shell);

    // Glass rim and small specular highlight.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, shortest * .018)
        ..shader = const SweepGradient(
          colors: [Color(0xFF8CEBFF), Color(0xFF6A8BFF), Color(0xFFE5A6FF), Color(0xFFFFD89A), Color(0xFF8CEBFF)],
        ).createShader(shellRect),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(-radius * .08, -radius * .08), radius: radius * .88),
      math.pi * 1.05,
      math.pi * .68,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.1, shortest * .026)
        ..color = Colors.white.withValues(alpha: .48),
    );

    // Inner organic energy: three softly overlapping fluid lobes.
    final drift = math.sin(phase) * radius * (active ? .12 : .065);
    final innerRect = Rect.fromCircle(center: center, radius: radius * .67);
    final energyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5EE7FF), Color(0xFF526BFF), Color(0xFFB56BFF), Color(0xFFFF9FD7)],
        stops: [0, .34, .70, 1],
      ).createShader(innerRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final lobe1 = Path()
      ..moveTo(center.dx - radius * .52, center.dy - radius * .05 + drift)
      ..cubicTo(center.dx - radius * .48, center.dy - radius * .52, center.dx - radius * .08, center.dy - radius * .47 - drift, center.dx + radius * .02, center.dy - radius * .14)
      ..cubicTo(center.dx + radius * .14, center.dy + radius * .13, center.dx - radius * .12, center.dy + radius * .42, center.dx - radius * .35, center.dy + radius * .25)
      ..cubicTo(center.dx - radius * .52, center.dy + radius * .13, center.dx - radius * .63, center.dy + radius * .13, center.dx - radius * .52, center.dy - radius * .05 + drift)
      ..close();
    canvas.drawPath(lobe1, energyPaint);

    final lobe2 = Path()
      ..moveTo(center.dx - radius * .10, center.dy - radius * .28 - drift)
      ..cubicTo(center.dx + radius * .12, center.dy - radius * .53, center.dx + radius * .56, center.dy - radius * .27, center.dx + radius * .48, center.dy + radius * .02)
      ..cubicTo(center.dx + radius * .43, center.dy + radius * .28, center.dx + radius * .11, center.dy + radius * .42 + drift, center.dx - radius * .06, center.dy + radius * .20)
      ..cubicTo(center.dx - radius * .18, center.dy + radius * .04, center.dx - radius * .25, center.dy - radius * .11, center.dx - radius * .10, center.dy - radius * .28 - drift)
      ..close();
    canvas.drawPath(lobe2, Paint()..color = violet.withValues(alpha: .83));

    // A luminous central core gives the orb its identity.
    final coreCenter = center.translate(radius * .12 + drift * .3, radius * .04);
    canvas.drawCircle(
      coreCenter,
      radius * .25,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: .98), pink.withValues(alpha: .95), violet.withValues(alpha: .70), Colors.transparent],
          stops: const [0, .22, .62, 1],
        ).createShader(Rect.fromCircle(center: coreCenter, radius: radius * .32)),
    );

    // Thin orbital rings are more visible while thinking, but remain restrained.
    final ringColor = isThinking ? const Color(0xFF6EDBFF) : gold;
    for (var i = 0; i < (isThinking ? 3 : 2); i++) {
      final ringRadius = radius * (.79 + i * .11);
      final rect = Rect.fromCenter(center: center, width: ringRadius * 2, height: ringRadius * (isThinking ? 1.35 : .72));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((time * (isThinking ? 1.0 : .35) * (i.isEven ? 1 : -1)) + i * .75);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(
        rect,
        phase + i * 1.8,
        isThinking ? math.pi * .9 : math.pi * .58,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.65, shortest * .009)
          ..strokeCap = StrokeCap.round
          ..color = ringColor.withValues(alpha: isThinking ? .54 : .30),
      );
      canvas.restore();
    }

    // Listening/speaking waveform appears inside the orb, without replacing its core.
    if (isSpeaking) {
      final waveY = center.dy;
      final wavePaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.0, shortest * .018);
      for (var i = 0; i < 7; i++) {
        final x = center.dx + (i - 3) * radius * .13;
        final strength = (1 - (i - 3).abs() / 4);
        final wave = radius * (.08 + strength * (.16 + .10 * math.sin(phase * 1.5 + i)));
        wavePaint.color = Color.lerp(const Color(0xFF72DFFF), pink, i / 6)!.withValues(alpha: .92);
        canvas.drawLine(Offset(x, waveY - wave), Offset(x, waveY + wave), wavePaint);
      }
    }

    // Small status spark: amber for ready, blue for processing, red for error.
    final statusColor = isError ? const Color(0xFFFF6B72) : isThinking ? const Color(0xFF68D9FF) : gold;
    final statusCenter = center.translate(radius * .77, -radius * .73);
    canvas.drawCircle(statusCenter, shortest * .035, Paint()..color = statusColor.withValues(alpha: .22));
    canvas.drawCircle(statusCenter, shortest * .018, Paint()..color = statusColor);
  }

  @override
  bool shouldRepaint(covariant _EinoOrbPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.mood != mood || oldDelegate.talking != talking ||
      oldDelegate.accent != accent || oldDelegate.showAura != showAura || oldDelegate.active != active;
}
