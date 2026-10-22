import 'dart:async';
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
    this.motionBoost = 0,
  });

  final double size;
  final bool talking;
  final EinoMood mood;
  final Color? accentColor;
  final bool showAura;
  /// 0..1 transition intensity supplied by the shell during enter/return.
  final double motionBoost;

  @override
  State<EinoFace> createState() => _EinoFaceState();
}

/// New semantic name for use in new code.
typedef EinoOrb = EinoFace;

class _EinoFaceState extends State<EinoFace> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();
  bool _lowActivity = false;
  bool _reduceMotion = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleIdle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _idleTimer?.cancel();
      _controller.stop(canceled: false);
    } else if (_lifecycleState == AppLifecycleState.resumed) {
      _controller.repeat();
      _scheduleIdle();
    }
  }

  @override
  void didUpdateWidget(covariant EinoFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moodChanged = oldWidget.mood != widget.mood || oldWidget.talking != widget.talking;
    final boostStartedOrEnded = (oldWidget.motionBoost <= .01) != (widget.motionBoost <= .01);
    final boostCrossedFastMotion = (oldWidget.motionBoost <= .05) != (widget.motionBoost <= .05);
    if (moodChanged || boostStartedOrEnded) _scheduleIdle();
    if (moodChanged || boostCrossedFastMotion) _syncMotionProfile();
  }

  void _syncMotionProfile() {
    if (_reduceMotion || _lifecycleState != AppLifecycleState.resumed) return;
    final fastTransition = widget.motionBoost > .05;
    final activeConversation = widget.talking || widget.mood == EinoMood.thinking || widget.mood == EinoMood.talking;
    final nextDuration = fastTransition
        ? const Duration(milliseconds: 680)
        : activeConversation
            ? const Duration(milliseconds: 1500)
            : _lowActivity
                ? const Duration(milliseconds: 14000)
                : const Duration(milliseconds: 4200);
    if (_controller.duration == nextDuration) return;
    _controller.duration = nextDuration;
    if (_controller.isAnimating) _controller.repeat();
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    if (_lowActivity) setState(() => _lowActivity = false);
    if (_reduceMotion) return;
    _syncMotionProfile();
    if (!_controller.isAnimating && _lifecycleState == AppLifecycleState.resumed) _controller.repeat();
    if (widget.motionBoost > .01 || widget.talking || widget.mood == EinoMood.thinking || widget.mood == EinoMood.talking) return;
    _idleTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || _lifecycleState != AppLifecycleState.resumed) return;
      setState(() => _lowActivity = true);
      _syncMotionProfile();
      _controller.repeat();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (!_reduceMotion && !_controller.isAnimating) _controller.repeat();
      if (!_reduceMotion) _scheduleIdle();
    } else {
      _idleTimer?.cancel();
      _controller.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isActive = widget.talking ||
        widget.mood == EinoMood.thinking ||
        widget.mood == EinoMood.talking || widget.motionBoost > .05;
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
                  lowActivity: _lowActivity && widget.motionBoost <= .01,
                  motionBoost: widget.motionBoost.clamp(0.0, 1.0).toDouble(),
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
    required this.lowActivity,
    required this.motionBoost,
  });

  final double time;
  final EinoMood mood;
  final bool talking;
  final Color accent;
  final bool showAura;
  final bool active;
  final bool lowActivity;
  /// 0..1 transition intensity supplied by the shell during enter/return.
  final double motionBoost;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    if (shortest <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortest * 0.355;
    final intensity = lowActivity ? .20 : (active ? 1.0 : .62) + motionBoost * 1.8;
    final phase = time * math.pi * 2 * (1 + motionBoost * 4.2);
    final fluidWave = math.sin(phase * 1.55) * radius * (lowActivity ? .018 : .085 * intensity);
    final fluidCounterWave = math.cos(phase * 1.18 + .8) * radius * (lowActivity ? .014 : .068 * intensity);
    final isError = mood == EinoMood.concerned;
    final isThinking = mood == EinoMood.thinking || mood == EinoMood.focused;
    final isSpeaking = talking || mood == EinoMood.talking;
    final isHappy = mood == EinoMood.happy || mood == EinoMood.proud;
    final isCurious = mood == EinoMood.curious || mood == EinoMood.surprised;
    final isConfused = mood == EinoMood.confused || mood == EinoMood.pouting;
    final blue = isError ? const Color(0xFFFF6B72) : isHappy ? const Color(0xFFFFC45C) : isCurious ? const Color(0xFF62F0D0) : isConfused ? const Color(0xFFFF91D2) : accent;
    const violet = Color(0xFF965CFF);
    const pink = Color(0xFFFF8FCF);
    const gold = Color(0xFFFFC875);

    // Soft ambient light, intentionally subtle at small floating-button sizes.
    if (showAura) {
      final aura = Paint()
        ..shader = RadialGradient(
          colors: [blue.withValues(alpha: (active ? .34 : .20) * (lowActivity ? .72 : 1 + motionBoost * .5)), violet.withValues(alpha: .08 + motionBoost * .10), Colors.transparent],
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
    final drift = math.sin(phase * 1.12) * radius * (lowActivity ? .025 : (active ? .17 : .10) * intensity) + fluidWave * .42;
    final innerRect = Rect.fromCircle(center: center, radius: radius * .67);
    final energyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5EE7FF), Color(0xFF526BFF), Color(0xFFB56BFF), Color(0xFFFF9FD7)],
        stops: [0, .34, .70, 1],
      ).createShader(innerRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    canvas.save();
    canvas.translate(
      math.sin(phase * .48) * radius * motionBoost * .22,
      math.cos(phase * .61) * radius * motionBoost * .18,
    );
    final lobe1 = Path()
      ..moveTo(center.dx - radius * .52 + fluidCounterWave * .24, center.dy - radius * .05 + drift)
      ..cubicTo(center.dx - radius * .48 + fluidWave * .26, center.dy - radius * .52 + fluidCounterWave * .34, center.dx - radius * .08 + fluidCounterWave * .28, center.dy - radius * .47 - drift - fluidWave * .20, center.dx + radius * .02 + fluidWave * .24, center.dy - radius * .14)
      ..cubicTo(center.dx + radius * .14 + fluidCounterWave * .24, center.dy + radius * .13 + fluidWave * .24, center.dx - radius * .12 - fluidWave * .22, center.dy + radius * .42 + fluidCounterWave * .25, center.dx - radius * .35, center.dy + radius * .25 + drift * .30)
      ..cubicTo(center.dx - radius * .52 - fluidWave * .18, center.dy + radius * .13 + fluidCounterWave * .18, center.dx - radius * .63 + fluidCounterWave * .20, center.dy + radius * .13, center.dx - radius * .52 + fluidCounterWave * .24, center.dy - radius * .05 + drift)
      ..close();
    canvas.drawPath(lobe1, energyPaint);

    final lobe2 = Path()
      ..moveTo(center.dx - radius * .10 + fluidWave * .18, center.dy - radius * .28 - drift)
      ..cubicTo(center.dx + radius * .12 + fluidCounterWave * .22, center.dy - radius * .53 - fluidWave * .24, center.dx + radius * .56 + fluidWave * .18, center.dy - radius * .27 + fluidCounterWave * .24, center.dx + radius * .48, center.dy + radius * .02 + fluidWave * .18)
      ..cubicTo(center.dx + radius * .43 - fluidWave * .18, center.dy + radius * .28, center.dx + radius * .11 + fluidCounterWave * .22, center.dy + radius * .42 + drift + fluidWave * .18, center.dx - radius * .06, center.dy + radius * .20 + fluidCounterWave * .20)
      ..cubicTo(center.dx - radius * .18 - fluidCounterWave * .18, center.dy + radius * .04 + fluidWave * .20, center.dx - radius * .25 + fluidWave * .18, center.dy - radius * .11, center.dx - radius * .10 + fluidWave * .18, center.dy - radius * .28 - drift)
      ..close();
    canvas.drawPath(lobe2, Paint()..color = violet.withValues(alpha: .83));
    canvas.restore();

    // A luminous central core gives the orb its identity.
    final moodOffset = isCurious ? math.sin(phase * .65) * radius * .08 : isConfused ? math.cos(phase * .7) * radius * .06 : 0.0;
    final coreCenter = center.translate(radius * .12 + drift * .3 + moodOffset, radius * .04 + (isHappy ? -radius * .04 : 0));
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
    final ringColor = isError ? const Color(0xFFFF6B72) : isThinking ? const Color(0xFF6EDBFF) : isHappy ? gold : isCurious ? const Color(0xFF62F0D0) : gold;
    final ringCount = isThinking || isCurious || motionBoost > .45 ? 3 : 2;
    for (var i = 0; i < ringCount; i++) {
      final ringRadius = radius * (.79 + i * .11);
      final rect = Rect.fromCenter(center: center, width: ringRadius * 2, height: ringRadius * (isThinking ? 1.35 : .72));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((phase * (isThinking ? 1.35 : .68) * (i.isEven ? 1 : -1) * intensity) + i * .75 + motionBoost * (i.isEven ? 2.2 : -1.8));
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
          ..color = ringColor.withValues(alpha: lowActivity ? .22 : isThinking ? .54 : .30 + motionBoost * .22),
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
    final statusCenter = center.translate(
      radius * (.77 + math.sin(phase * .72) * (lowActivity ? .012 : .055 * intensity)),
      radius * (-.73 + math.cos(phase * .91) * (lowActivity ? .010 : .045 * intensity)),
    );
    canvas.drawCircle(statusCenter, shortest * (.035 + motionBoost * .012), Paint()..color = statusColor.withValues(alpha: lowActivity ? .12 : .22 + motionBoost * .22));
    canvas.drawCircle(statusCenter, shortest * (.018 + motionBoost * .008), Paint()..color = statusColor);

    // During entry/return, tiny luminous motes travel around the shell. This
    // makes the fluid feel as if it is spilling through the orbital rings.
    if (motionBoost > .02) {
      for (var i = 0; i < 5; i++) {
        final angle = phase * (1.35 + i * .08) + i * (math.pi * 2 / 5);
        final orbit = radius * (.82 + motionBoost * (.24 + .10 * math.sin(phase + i)));
        final mote = center.translate(math.cos(angle) * orbit, math.sin(angle) * orbit * .72);
        final moteRadius = shortest * (.012 + motionBoost * .008) * (1 - i * .08);
        canvas.drawCircle(mote, moteRadius * 2.8, Paint()..color = ringColor.withValues(alpha: .10 + motionBoost * .18));
        canvas.drawCircle(mote, moteRadius, Paint()..color = Colors.white.withValues(alpha: .45 + motionBoost * .45));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EinoOrbPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.mood != mood || oldDelegate.talking != talking ||
      oldDelegate.accent != accent || oldDelegate.showAura != showAura || oldDelegate.active != active ||
      oldDelegate.lowActivity != lowActivity || oldDelegate.motionBoost != motionBoost;
}
