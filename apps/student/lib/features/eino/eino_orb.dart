import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Marks a chat entry and carries a one-shot return cue across route teardown.
/// The floating orb lives inside ShellRoute while Eino chat is a top-level route,
/// so ordinary widget state would otherwise be lost when the chat opens.
class EinoMotionSession {
  EinoMotionSession._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static bool _returnAnimationPending = false;
  static bool _chatOpen = false;

  static bool get chatOpen => _chatOpen;

  static void markChatOpened() {
    _returnAnimationPending = false;
    _chatOpen = true;
    changes.value++;
  }

  static void markChatClosed() {
    if (!_chatOpen) return;
    _chatOpen = false;
    _returnAnimationPending = true;
    changes.value++;
  }

  static bool consumeReturnAnimation() {
    // The pending cue is created only when an actual chat screen is disposed.
    // The floating button listens to changes, so the cue survives covered routes.
    if (!_returnAnimationPending || _chatOpen) return false;
    _returnAnimationPending = false;
    return true;
  }
}

/// Lightweight glass-like Eino core with visibly moving liquid material and
/// light particles. After inactivity it keeps a low-motion breathing drift.
class EinoOrb extends StatefulWidget {
  const EinoOrb({
    required this.size,
    required this.accent,
    this.onTap,
    this.sleepAfter = const Duration(seconds: 30),
    this.returningFromChat = false,
    this.suspendWhileChatOpen = false,
    super.key,
  });

  final double size;
  final Color accent;
  final VoidCallback? onTap;
  final Duration sleepAfter;
  final bool returningFromChat;
  final bool suspendWhileChatOpen;

  @override
  State<EinoOrb> createState() => _EinoOrbState();
}

class _EinoOrbState extends State<EinoOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  Timer? _sleepTimer;
  Timer? _boostTimer;
  bool _sleeping = false;
  bool _boosted = false;
  bool _returning = false;
  bool _reducedMotion = false;
  bool _pausedForChat = false;

  @override
  void initState() {
    super.initState();
    if (widget.suspendWhileChatOpen) {
      EinoMotionSession.changes.addListener(_handleChatSessionChange);
      _pausedForChat = EinoMotionSession.chatOpen;
    }
    if (widget.returningFromChat) {
      _boosted = true;
      _returning = true;
    }
    _updateMotion();
    if (widget.returningFromChat) _finishBoostAfter(const Duration(milliseconds: 1450));
    _armSleepTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant EinoOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suspendWhileChatOpen != widget.suspendWhileChatOpen) {
      if (widget.suspendWhileChatOpen) {
        EinoMotionSession.changes.addListener(_handleChatSessionChange);
        _pausedForChat = EinoMotionSession.chatOpen;
      } else {
        EinoMotionSession.changes.removeListener(_handleChatSessionChange);
        _pausedForChat = false;
      }
      _updateMotion();
    }
    if (!oldWidget.returningFromChat && widget.returningFromChat) {
      _boostMotion(returning: true);
      _armSleepTimer();
    }
  }

  void _handleChatSessionChange() {
    if (!mounted || !widget.suspendWhileChatOpen) return;
    if (EinoMotionSession.chatOpen) {
      _pausedForChat = true;
      _sleepTimer?.cancel();
      _boostTimer?.cancel();
      _motion.stop();
      return;
    }
    if (_pausedForChat) {
      _pausedForChat = false;
      _updateMotion();
      _armSleepTimer();
    }
  }

  void _armSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(widget.sleepAfter, () {
      if (!mounted) return;
      setState(() {
        _sleeping = true;
        _boosted = false;
        _returning = false;
      });
      _boostTimer?.cancel();
      _updateMotion();
    });
  }

  void _finishBoostAfter(Duration duration) {
    _boostTimer?.cancel();
    _boostTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _boosted = false;
        _returning = false;
      });
      _updateMotion();
    });
  }

  void _boostMotion({required bool returning}) {
    _boostTimer?.cancel();
    setState(() {
      _sleeping = false;
      _boosted = true;
      _returning = returning;
    });
    _updateMotion();
    _finishBoostAfter(Duration(milliseconds: returning ? 1450 : 1150));
  }

  void _updateMotion() {
    if (_pausedForChat || (widget.suspendWhileChatOpen && EinoMotionSession.chatOpen)) {
      _motion.stop();
      return;
    }
    if (_reducedMotion) {
      _motion.stop();
      _motion.value = 0.18;
      return;
    }
    _motion.duration = Duration(
      milliseconds: _sleeping ? 12000 : (_boosted ? 520 : 2300),
    );
    if (!_motion.isAnimating) _motion.repeat();
  }

  void _handleTap() {
    _boostMotion(returning: false);
    _armSleepTimer();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    if (widget.suspendWhileChatOpen) {
      EinoMotionSession.changes.removeListener(_handleChatSessionChange);
    }
    _sleepTimer?.cancel();
    _boostTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: widget.onTap != null,
      label: _sleeping ? 'Eino assistant sleeping' : 'Eino assistant active',
      child: GestureDetector(
        onTap: widget.onTap == null ? null : _handleTap,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final phase = _motion.value * math.pi * 2;
            final amplitude = _sleeping ? 0.035 : (_boosted ? 0.27 : 0.15);
            final glow = (_sleeping ? 0.10 : 0.20) +
                (math.sin(phase) + 1) * amplitude * 0.5;
            return SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _EinoOrbPainter(
                  phase: phase,
                  accent: widget.accent,
                  sleeping: _sleeping,
                  boosted: _boosted,
                  returning: _returning,
                  glow: glow,
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
    required this.phase,
    required this.accent,
    required this.sleeping,
    required this.boosted,
    required this.returning,
    required this.glow,
  });

  final double phase;
  final Color accent;
  final bool sleeping;
  final bool boosted;
  final bool returning;
  final double glow;

  Path _liquidPath(Offset center, double radius, double phase, double strength) {
    const points = 36;
    final path = Path();
    for (var i = 0; i < points; i++) {
      final angle = (i / points) * math.pi * 2;
      final wave = math.sin(angle * 2.0 + phase * 0.86) * 0.075 +
          math.cos(angle * 3.0 - phase * 0.61) * 0.045 +
          math.sin(angle + phase * 0.47) * 0.035;
      final r = radius * (0.58 + wave * strength);
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.43;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final movement = sleeping ? 0.27 : (boosted ? 1.65 : 1.0);
    final motionPhase = phase * movement;

    // Outer atmospheric glow and reflective glass sphere.
    canvas.drawCircle(
      center,
      radius * (returning ? 1.28 : 1.19),
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: glow.clamp(0.0, 0.8).toDouble()),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            -0.35 + math.sin(motionPhase) * (boosted ? 0.20 : 0.11),
            -0.4 + math.cos(motionPhase * 0.72) * 0.08,
          ),
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Color.lerp(accent, Colors.white, 0.52)!,
            Color.lerp(accent, Colors.black, 0.38)!,
          ],
          stops: const [0, 0.34, 1],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));

    // Main liquid body changes its contour every frame instead of being a
    // static circle. It becomes more energetic during wake/return transitions.
    final liquidPath = _liquidPath(
      center,
      radius,
      motionPhase,
      sleeping ? 0.32 : (boosted ? 1.75 : 1.0),
    );
    canvas.drawPath(
      liquidPath,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            math.sin(motionPhase * 0.8) * 0.45,
            math.cos(motionPhase * 0.66) * 0.40,
          ),
          colors: [
            Colors.white.withValues(alpha: sleeping ? 0.30 : 0.62),
            Color.lerp(accent, Colors.white, 0.60)!
                .withValues(alpha: sleeping ? 0.43 : 0.83),
            accent.withValues(alpha: sleeping ? 0.30 : 0.70),
          ],
        ).createShader(bounds)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.012),
    );

    final blobPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.045);
    final travel = sleeping ? 0.045 : (boosted ? 0.27 : 0.17);
    final blobOne = Offset(
      center.dx + math.cos(motionPhase) * radius * travel,
      center.dy + math.sin(motionPhase * 0.8) * radius * travel,
    );
    final blobTwo = Offset(
      center.dx + math.sin(motionPhase * 0.7 + 1.4) * radius * travel,
      center.dy + math.cos(motionPhase * 0.9 + 1.4) * radius * travel,
    );
    blobPaint.color = Colors.white.withValues(alpha: sleeping ? 0.25 : 0.54);
    canvas.drawCircle(blobOne, radius * (sleeping ? 0.23 : 0.32), blobPaint);
    blobPaint.color = accent.withValues(alpha: sleeping ? 0.24 : 0.44);
    canvas.drawCircle(blobTwo, radius * (sleeping ? 0.25 : 0.36), blobPaint);

    // Four small luminous particles follow different looping paths inside the
    // core; in sleep mode they drift slowly rather than stopping altogether.
    final particleSpeed = sleeping ? 0.24 : (boosted ? 1.9 : 1.0);
    for (var i = 0; i < 4; i++) {
      final particlePhase = motionPhase * particleSpeed + i * math.pi / 2;
      final particle = Offset(
        center.dx + math.cos(particlePhase) * radius * 0.48,
        center.dy + math.sin(particlePhase * 1.28 + i * 0.55) * radius * 0.42,
      );
      final particleRadius = radius * (returning ? 0.050 : 0.038);
      canvas.drawCircle(
        particle,
        particleRadius * 2.0,
        Paint()
          ..color = Colors.white.withValues(alpha: sleeping ? 0.12 : 0.32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleRadius * 1.7),
      );
      canvas.drawCircle(
        particle,
        particleRadius,
        Paint()..color = Colors.white.withValues(alpha: sleeping ? 0.38 : 0.95),
      );
    }

    final filament = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * (boosted ? 0.024 : 0.018)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: sleeping ? 0.26 : 0.65);
    final filamentPath = Path()
      ..moveTo(center.dx - radius * 0.52, center.dy + radius * 0.12)
      ..cubicTo(
        center.dx - radius * 0.15,
        center.dy - radius * (0.45 + travel * math.sin(motionPhase)),
        center.dx + radius * 0.20,
        center.dy + radius * (0.48 + travel * math.cos(motionPhase)),
        center.dx + radius * 0.55,
        center.dy - radius * 0.12,
      );
    canvas.drawPath(filamentPath, filament);
    canvas.restore();

    // The return cue is a gentle expanding halo. The controller remains in its
    // faster phase briefly, then the orb eases back to its normal breathing speed.
    if (returning) {
      final returnProgress = (0.5 + 0.5 * math.sin(phase * 0.7)).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        center,
        radius * (1.10 + returnProgress * 0.18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.022
          ..color = Colors.white.withValues(alpha: 0.14 + returnProgress * 0.22),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * 0.025)
        ..color = Colors.white.withValues(alpha: 0.72),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.08),
      phase * (boosted ? 0.48 : 0.22),
      math.pi * (returning ? 0.84 : 0.62),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, size.width * 0.018)
        ..color = accent.withValues(alpha: sleeping ? 0.32 : 0.72),
    );
    canvas.drawCircle(
      Offset(
        center.dx - radius * 0.32 + math.sin(motionPhase * 0.8) * radius * 0.08,
        center.dy - radius * 0.45 + math.cos(motionPhase * 0.7) * radius * 0.06,
      ),
      radius * 0.075,
      Paint()..color = Colors.white.withValues(alpha: sleeping ? 0.45 : 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _EinoOrbPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.accent != accent ||
      oldDelegate.sleeping != sleeping ||
      oldDelegate.boosted != boosted ||
      oldDelegate.returning != returning ||
      oldDelegate.glow != glow;
}
