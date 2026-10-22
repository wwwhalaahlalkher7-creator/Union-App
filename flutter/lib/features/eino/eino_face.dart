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
    final radius = shortest * .315;
    final boost = motionBoost.clamp(0.0, 1.0).toDouble();
    final energy = lowActivity ? .20 : (active ? 1.0 : .68);
    final phase = time * math.pi * 2;
    final drift = math.sin(phase) * radius * (.018 + .025 * energy) * (1 + boost * 2.2);
    final breathing = 1 + math.sin(phase * .5) * (lowActivity ? .008 : .018 + boost * .012);

    final isError = mood == EinoMood.concerned;
    final isThinking = mood == EinoMood.thinking || mood == EinoMood.focused;
    final isSpeaking = talking || mood == EinoMood.talking;
    final isHappy = mood == EinoMood.happy || mood == EinoMood.proud;
    final isCurious = mood == EinoMood.curious || mood == EinoMood.surprised;
    final isConfused = mood == EinoMood.confused || mood == EinoMood.pouting;
    final moodColor = isError
        ? const Color(0xFFFF697A)
        : isHappy
            ? const Color(0xFFFFC86B)
            : isCurious
                ? const Color(0xFF68E8D4)
                : isConfused
                    ? const Color(0xFFFF91C8)
                    : isThinking
                        ? const Color(0xFF70CFFF)
                        : accent;
    const violet = Color(0xFF9C7BFF);
    const cyan = Color(0xFF82F0F5);
    const rose = Color(0xFFFFA8D7);
    final ringAlpha = lowActivity ? .22 : (.36 + boost * .28);

    // Ambient halo: one soft, broad glow rather than several competing effects.
    if (showAura) {
      final haloRadius = radius * (2.05 + boost * .18);
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              moodColor.withValues(alpha: (lowActivity ? .14 : .23) + boost * .12),
              violet.withValues(alpha: .075 + boost * .06),
              Colors.transparent,
            ],
            stops: const [0, .48, 1],
          ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
      );
    }

    // Two restrained orbital tracks. Their directions differ to create depth,
    // while their speed follows the idle / active / transition profile.
    final orbitSpeed = lowActivity ? .22 : (isThinking ? 1.05 : .62) + boost * 2.8;
    for (var i = 0; i < 2; i++) {
      final orbitRadius = radius * (1.28 + i * .18);
      final orbitRect = Rect.fromCenter(
        center: center,
        width: orbitRadius * 2,
        height: orbitRadius * (i == 0 ? .62 : .92),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(phase * orbitSpeed * (i == 0 ? 1 : -.72) + i * 1.1);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(
        orbitRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.8, shortest * .012)
          ..color = moodColor.withValues(alpha: ringAlpha * (i == 0 ? 1 : .72)),
      );
      canvas.drawArc(
        orbitRect,
        phase * orbitSpeed * (i == 0 ? -.55 : .7) + i * 1.7,
        math.pi * (i == 0 ? .40 : .27),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1.2, shortest * .025)
          ..color = Colors.white.withValues(alpha: lowActivity ? .28 : .66),
      );
      canvas.restore();
    }

    final orbCenter = center.translate(0, drift);
    final orbRadius = radius * breathing;
    final orbRect = Rect.fromCircle(center: orbCenter, radius: orbRadius);

    // The glass body has a stable silhouette; only its light moves, avoiding
    // the distorted overlapping blobs that made the previous animation noisy.
    canvas.drawCircle(
      orbCenter,
      orbRadius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-.38 + math.sin(phase * .55) * .06, -.55),
          radius: 1.18,
          colors: [
            Color.lerp(const Color(0xFFB6F7FF), moodColor, .34)!,
            const Color(0xFF344B83),
            const Color(0xFF151D3D),
            const Color(0xFF080D20),
          ],
          stops: const [0, .27, .68, 1],
        ).createShader(orbRect),
    );

    // A single luminous ribbon flows through the core. Its curves stay smooth
    // and continuous, with restrained amplitude at rest and more energy on tap.
    canvas.save();
    canvas.clipPath(Path()..addOval(orbRect.deflate(orbRadius * .055)));
    final ribbonRect = orbRect.inflate(orbRadius * .12);
    final ribbonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cyan.withValues(alpha: .90), moodColor.withValues(alpha: .90), violet.withValues(alpha: .82), rose.withValues(alpha: .74)],
      ).createShader(ribbonRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, shortest * .038)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    final waveY = orbCenter.dy + math.sin(phase * .72) * orbRadius * .16;
    final waveAmplitude = orbRadius * (lowActivity ? .12 : .22 + boost * .10);
    final wave = Path()
      ..moveTo(orbCenter.dx - orbRadius * 1.12, waveY + math.sin(phase) * waveAmplitude * .30)
      ..cubicTo(
        orbCenter.dx - orbRadius * .62,
        waveY - waveAmplitude * math.cos(phase * .78),
        orbCenter.dx - orbRadius * .28,
        waveY + waveAmplitude * math.sin(phase * .83 + .7),
        orbCenter.dx + orbRadius * .02,
        waveY,
      )
      ..cubicTo(
        orbCenter.dx + orbRadius * .34,
        waveY - waveAmplitude * math.sin(phase * .83 + .7),
        orbCenter.dx + orbRadius * .64,
        waveY + waveAmplitude * math.cos(phase * .78),
        orbCenter.dx + orbRadius * 1.12,
        waveY + math.sin(phase) * waveAmplitude * .25,
      );
    canvas.drawPath(wave, ribbonPaint);

    // The inner light moves gently across the ribbon to make the core feel alive.
    final coreCenter = orbCenter.translate(
      math.sin(phase * .56) * orbRadius * (isCurious ? .22 : .13),
      math.cos(phase * .68) * orbRadius * (isHappy ? .12 : .08),
    );
    final coreRadius = orbRadius * (isSpeaking ? .20 + .025 * math.sin(phase * 3) : .17);
    canvas.drawCircle(
      coreCenter,
      coreRadius * 1.65,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .48), moodColor.withValues(alpha: .20), Colors.transparent])
            .createShader(Rect.fromCircle(center: coreCenter, radius: coreRadius * 1.65)),
    );
    canvas.drawCircle(
      coreCenter,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, cyan.withValues(alpha: .94), moodColor.withValues(alpha: .72), Colors.transparent],
          stops: const [0, .26, .66, 1],
        ).createShader(Rect.fromCircle(center: coreCenter, radius: coreRadius * 1.28)),
    );
    canvas.restore();

    // Glass rim and a single moving specular highlight.
    canvas.drawCircle(
      orbCenter,
      orbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, shortest * .018)
        ..shader = SweepGradient(
          transform: GradientRotation(phase * (lowActivity ? .08 : .24 + boost * .8)),
          colors: [cyan.withValues(alpha: .82), moodColor.withValues(alpha: .72), violet.withValues(alpha: .66), Colors.white.withValues(alpha: .86), cyan.withValues(alpha: .82)],
        ).createShader(orbRect),
    );
    canvas.drawArc(
      Rect.fromCircle(center: orbCenter.translate(-orbRadius * .08, -orbRadius * .08), radius: orbRadius * .84),
      math.pi * (1.05 + math.sin(phase * .3) * .035),
      math.pi * .47,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.0, shortest * .024)
        ..color = Colors.white.withValues(alpha: lowActivity ? .30 : .54),
    );

    // A small orbiting signal dot communicates state without cluttering the orb.
    final signalAngle = phase * (lowActivity ? .16 : .48 + boost * 2.4) - math.pi * .35;
    final signalRadius = radius * 1.48;
    final signalCenter = center.translate(
      math.cos(signalAngle) * signalRadius,
      math.sin(signalAngle) * signalRadius * .58,
    );
    canvas.drawCircle(
      signalCenter,
      shortest * .048,
      Paint()..color = moodColor.withValues(alpha: lowActivity ? .12 : .24),
    );
    canvas.drawCircle(
      signalCenter,
      shortest * .020,
      Paint()..color = Colors.white.withValues(alpha: lowActivity ? .55 : .92),
    );

    // Speech becomes a subtle pulse of three light bars, not a separate noisy layer.
    if (isSpeaking) {
      for (var i = -1; i <= 1; i++) {
        final barHeight = shortest * (.035 + .045 * (0.5 + .5 * math.sin(phase * 2.8 + i * .9)));
        final barCenter = orbCenter.translate(i * shortest * .075, orbRadius * .48);
        canvas.drawLine(
          Offset(barCenter.dx, barCenter.dy - barHeight),
          Offset(barCenter.dx, barCenter.dy + barHeight),
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(1.0, shortest * .018)
            ..color = Colors.white.withValues(alpha: .76),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EinoOrbPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.mood != mood || oldDelegate.talking != talking ||
      oldDelegate.accent != accent || oldDelegate.showAura != showAura || oldDelegate.active != active ||
      oldDelegate.lowActivity != lowActivity || oldDelegate.motionBoost != motionBoost;
}
