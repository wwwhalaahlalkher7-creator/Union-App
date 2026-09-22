import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

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

  // Backward-compatibility aliases
  static const EinoMood idle = EinoMood.calm;
  static const EinoMood error = EinoMood.concerned;
}

/// Expressive anime-style AI Assistant character for TRINEX.
/// Features smooth 60fps vector animations (breathing, blinking, lip-sync, mood expressions)
/// designed to be lightweight and render with pristine clarity at any resolution.
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

class _EinoFaceState extends State<EinoFace> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.talking || widget.mood == EinoMood.thinking || widget.mood == EinoMood.talking;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final primaryAccent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return TickerMode(
      enabled: !reduceMotion,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * math.pi;
          final breath = math.sin(t) * (active ? 0.03 : 0.015);
          final bob = math.sin(t) * (widget.size * 0.02);
          final tilt = math.sin(t * 0.5) * (widget.mood == EinoMood.curious ? 0.08 : 0.02);

          return Transform.translate(
            offset: Offset(0, bob),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: 1 + breath,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _EinoAnimePainter(
                      mood: widget.mood,
                      talking: widget.talking,
                      time: _controller.value,
                      accent: primaryAccent,
                      showAura: widget.showAura,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EinoAnimePainter extends CustomPainter {
  _EinoAnimePainter({
    required this.mood,
    required this.talking,
    required this.time,
    required this.accent,
    required this.showAura,
  });

  final EinoMood mood;
  final bool talking;
  final double time;
  final Color accent;
  final bool showAura;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final r = w * 0.42;

    // Outer subtle ambient glow
    if (showAura) {
      final auraColor = switch (mood) {
        EinoMood.concerned => AppColors.danger,
        EinoMood.happy || EinoMood.proud => accent,
        EinoMood.thinking => const Color(0xFF6366F1),
        _ => accent,
      };
      final auraPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            auraColor.withValues(alpha: 0.22),
            auraColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.25));
      canvas.drawCircle(center, r * 1.22, auraPaint);
    }

    // Circular background badge
    final bgPaint = Paint()..color = Color.lerp(const Color(0xFF0B1320), accent, .10)!;
    canvas.drawCircle(center, r, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, w * 0.028)
      ..color = accent.withValues(alpha: 0.85);
    canvas.drawCircle(center, r, borderPaint);

    // Dynamic tech ring indicator
    final techRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.015)
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.4);
    final rotAngle = time * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.94), rotAngle, math.pi * 0.7, false, techRing);

    // --- CHARACTER DRAWING ---
    // Clip character inside the circle badge
    canvas.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: r - 1));
    canvas.clipPath(clipPath);

    // Neck & Collar
    final neckPaint = Paint()..color = const Color(0xFFF3D5C5);
    final neckPath = Path()
      ..moveTo(center.dx - r * 0.22, center.dy + r * 0.45)
      ..lineTo(center.dx + r * 0.22, center.dy + r * 0.45)
      ..lineTo(center.dx + r * 0.28, center.dy + r * 1.1)
      ..lineTo(center.dx - r * 0.28, center.dy + r * 1.1)
      ..close();
    canvas.drawPath(neckPath, neckPaint);

    // Engineering hoodie / shirt collar
    final collarPaint = Paint()..color = Color.lerp(const Color(0xFF172231), accent, .18)!;
    final collarPath = Path()
      ..moveTo(center.dx - r * 0.55, center.dy + r * 0.85)
      ..quadraticBezierTo(center.dx, center.dy + r * 0.65, center.dx + r * 0.55, center.dy + r * 0.85)
      ..lineTo(center.dx + r * 0.6, center.dy + r * 1.2)
      ..lineTo(center.dx - r * 0.6, center.dy + r * 1.2)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    // Accent tie/stripe
    final stripePaint = Paint()..color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.88), width: r * 0.14, height: r * 0.28),
        Radius.circular(r * 0.06),
      ),
      stripePaint,
    );

    // Back hair
    final backHairPaint = Paint()..color = const Color(0xFF16202E);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.1), width: r * 1.45, height: r * 1.35),
      backHairPaint,
    );

    // Face base (smooth anime chin)
    final skinPaint = Paint()..color = const Color(0xFFFFF2EB);
    final facePath = Path()
      ..moveTo(center.dx - r * 0.5, center.dy - r * 0.2)
      ..cubicTo(
        center.dx - r * 0.5, center.dy + r * 0.25,
        center.dx - r * 0.35, center.dy + r * 0.58,
        center.dx, center.dy + r * 0.62,
      )
      ..cubicTo(
        center.dx + r * 0.35, center.dy + r * 0.58,
        center.dx + r * 0.5, center.dy + r * 0.25,
        center.dx + r * 0.5, center.dy - r * 0.2,
      )
      ..close();
    canvas.drawPath(facePath, skinPaint);

    // Cheerful blush
    final isBlushing = mood == EinoMood.happy || mood == EinoMood.proud || mood == EinoMood.pouting;
    final blushPaint = Paint()
      ..color = (isBlushing ? const Color(0xFFF87171) : const Color(0xFFFCA5A5))
          .withValues(alpha: isBlushing ? 0.45 : 0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx - r * 0.34, center.dy + r * 0.22), width: r * 0.24, height: r * 0.12), blushPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx + r * 0.34, center.dy + r * 0.22), width: r * 0.24, height: r * 0.12), blushPaint);

    // Headset / smart hair accessory band
    final bandPaint = Paint()
      ..color = const Color(0xFF2E384D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, w * 0.04);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy - r * 0.12), width: r * 1.28, height: r * 1.25),
      -math.pi * 0.9,
      math.pi * 0.8,
      false,
      bandPaint,
    );

    // Smart ear-piece / headphone badge on right side
    final earPhonePaint = Paint()..color = accent;
    canvas.drawCircle(Offset(center.dx + r * 0.56, center.dy - r * 0.05), r * 0.14, earPhonePaint);
    canvas.drawCircle(Offset(center.dx + r * 0.56, center.dy - r * 0.05), r * 0.07, Paint()..color = Colors.white);

    // Anime Hair: Front bangs & stylish locks
    final hairPaint = Paint()..color = const Color(0xFF222F3E);
    final hairPath = Path();

    // Left bangs
    hairPath.moveTo(center.dx - r * 0.56, center.dy - r * 0.2);
    hairPath.quadraticBezierTo(center.dx - r * 0.45, center.dy - r * 0.55, center.dx, center.dy - r * 0.52);
    hairPath.quadraticBezierTo(center.dx + r * 0.45, center.dy - r * 0.55, center.dx + r * 0.56, center.dy - r * 0.2);
    hairPath.lineTo(center.dx + r * 0.52, center.dy + r * 0.25);
    hairPath.quadraticBezierTo(center.dx + r * 0.42, center.dy + r * 0.05, center.dx + r * 0.35, center.dy - r * 0.05);
    // Center-right bang
    hairPath.lineTo(center.dx + r * 0.15, center.dy + r * 0.08);
    hairPath.lineTo(center.dx + r * 0.05, center.dy - r * 0.12);
    // Center-left bang
    hairPath.lineTo(center.dx - r * 0.12, center.dy + r * 0.06);
    hairPath.lineTo(center.dx - r * 0.22, center.dy - r * 0.1);
    // Left cheek lock
    hairPath.lineTo(center.dx - r * 0.38, center.dy + r * 0.22);
    hairPath.lineTo(center.dx - r * 0.52, center.dy + r * 0.15);
    hairPath.close();
    canvas.drawPath(hairPath, hairPaint);

    // Hair specular highlight arc (subtle anime shine)
    final hairSheen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.02)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy - r * 0.32), width: r * 0.8, height: r * 0.4),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      hairSheen,
    );

    // --- EYES & EYEBROWS ---
    final blinkCycle = math.sin(time * math.pi * 2 * 1.5).abs();
    final isBlinking = blinkCycle > 0.96 && mood != EinoMood.surprised;

    _drawAnimeEye(canvas, center: Offset(center.dx - r * 0.26, center.dy + r * 0.04), r: r, isLeft: true, blink: isBlinking);
    _drawAnimeEye(canvas, center: Offset(center.dx + r * 0.26, center.dy + r * 0.04), r: r, isLeft: false, blink: isBlinking);

    // Eyebrows
    _drawEyebrows(canvas, center: center, r: r);

    // Nose (delicate anime dot)
    final nosePaint = Paint()
      ..color = const Color(0xFFD98A78)
      ..strokeWidth = math.max(1.2, w * 0.016)
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, [Offset(center.dx, center.dy + r * 0.23)], nosePaint);

    // Mouth
    _drawMouth(canvas, center: center, r: r, time: time);

    canvas.restore(); // end clip
  }

  void _drawAnimeEye(Canvas canvas, {required Offset center, required double r, required bool isLeft, required bool blink}) {
    if (blink) {
      final linePaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, r * 0.06)
        ..strokeCap = StrokeCap.round;
      final y = center.dy + r * 0.04;
      final path = Path()
        ..moveTo(center.dx - r * 0.14, y)
        ..quadraticBezierTo(center.dx, y - r * 0.03, center.dx + r * 0.14, y);
      canvas.drawPath(path, linePaint);
      return;
    }

    final eyeWidth = r * 0.26;
    final eyeHeight = mood == EinoMood.surprised ? r * 0.36 : r * 0.31;

    // Sclera (White background)
    final scleraPaint = Paint()..color = Colors.white;
    final eyeRect = Rect.fromCenter(center: center, width: eyeWidth, height: eyeHeight);
    canvas.drawOval(eyeRect, scleraPaint);

    // Iris (Rich gradient sapphire / teal)
    final irisCenter = Offset(
      center.dx + (mood == EinoMood.curious ? (isLeft ? -r * 0.03 : r * 0.02) : 0),
      center.dy + (mood == EinoMood.thinking ? -r * 0.03 : r * 0.02),
    );
    final irisPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(Colors.white, accent, .92)!,
          accent,
          Color.lerp(const Color(0xFF0B1320), accent, .38)!,
        ],
      ).createShader(
        Rect.fromCircle(center: irisCenter, radius: eyeWidth * 0.4),
      );
    canvas.drawOval(Rect.fromCenter(center: irisCenter, width: eyeWidth * 0.76, height: eyeHeight * 0.88), irisPaint);

    // Dark Pupil
    final pupilPaint = Paint()..color = const Color(0xFF07101C);
    canvas.drawCircle(irisCenter, eyeWidth * 0.22, pupilPaint);

    // Specular anime sparkles (twin glints for living anime feel)
    final spark1 = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(irisCenter.dx - eyeWidth * 0.14, irisCenter.dy - eyeHeight * 0.16), eyeWidth * 0.12, spark1);
    final spark2 = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(irisCenter.dx + eyeWidth * 0.12, irisCenter.dy + eyeHeight * 0.12), eyeWidth * 0.065, spark2);

    // Upper eyelash outline and gentle wing
    final lashPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, r * 0.065)
      ..strokeCap = StrokeCap.round;
    final lashPath = Path()
      ..moveTo(center.dx - eyeWidth * 0.55, center.dy - eyeHeight * 0.25)
      ..quadraticBezierTo(center.dx, center.dy - eyeHeight * 0.62, center.dx + eyeWidth * 0.55, center.dy - eyeHeight * 0.25);
    canvas.drawPath(lashPath, lashPaint);

    // Little stylish corner wing
    final wingX = isLeft ? center.dx - eyeWidth * 0.62 : center.dx + eyeWidth * 0.62;
    canvas.drawLine(
      Offset(isLeft ? center.dx - eyeWidth * 0.5 : center.dx + eyeWidth * 0.5, center.dy - eyeHeight * 0.3),
      Offset(wingX, center.dy - eyeHeight * 0.38),
      lashPaint..strokeWidth = math.max(1.5, r * 0.045),
    );
  }

  void _drawEyebrows(Canvas canvas, {required Offset center, required double r}) {
    final browPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, r * 0.045)
      ..strokeCap = StrokeCap.round;

    final y = center.dy - r * 0.18;

    final leftBrow = Path();
    final rightBrow = Path();

    switch (mood) {
      case EinoMood.happy:
      case EinoMood.proud:
        leftBrow.moveTo(center.dx - r * 0.38, y + r * 0.03);
        leftBrow.quadraticBezierTo(center.dx - r * 0.25, y - r * 0.04, center.dx - r * 0.12, y + r * 0.02);
        rightBrow.moveTo(center.dx + r * 0.12, y + r * 0.02);
        rightBrow.quadraticBezierTo(center.dx + r * 0.25, y - r * 0.04, center.dx + r * 0.38, y + r * 0.03);
        break;
      case EinoMood.curious:
      case EinoMood.confused:
        // One raised, one tilted
        leftBrow.moveTo(center.dx - r * 0.38, y - r * 0.04);
        leftBrow.quadraticBezierTo(center.dx - r * 0.25, y - r * 0.09, center.dx - r * 0.12, y - r * 0.03);
        rightBrow.moveTo(center.dx + r * 0.12, y + r * 0.03);
        rightBrow.quadraticBezierTo(center.dx + r * 0.25, y, center.dx + r * 0.38, y + r * 0.02);
        break;
      case EinoMood.thinking:
      case EinoMood.focused:
        // Focused slightly knit inward
        leftBrow.moveTo(center.dx - r * 0.38, y - r * 0.02);
        leftBrow.quadraticBezierTo(center.dx - r * 0.25, y, center.dx - r * 0.12, y + r * 0.04);
        rightBrow.moveTo(center.dx + r * 0.12, y + r * 0.04);
        rightBrow.quadraticBezierTo(center.dx + r * 0.25, y, center.dx + r * 0.38, y - r * 0.02);
        break;
      case EinoMood.concerned:
        // Worried arch (slanted upward toward center)
        leftBrow.moveTo(center.dx - r * 0.38, y + r * 0.04);
        leftBrow.quadraticBezierTo(center.dx - r * 0.25, y, center.dx - r * 0.12, y - r * 0.04);
        rightBrow.moveTo(center.dx + r * 0.12, y - r * 0.04);
        rightBrow.quadraticBezierTo(center.dx + r * 0.25, y, center.dx + r * 0.38, y + r * 0.04);
        break;
      default:
        // Calm / gentle natural arch
        leftBrow.moveTo(center.dx - r * 0.38, y);
        leftBrow.quadraticBezierTo(center.dx - r * 0.25, y - r * 0.04, center.dx - r * 0.12, y);
        rightBrow.moveTo(center.dx + r * 0.12, y);
        rightBrow.quadraticBezierTo(center.dx + r * 0.25, y - r * 0.04, center.dx + r * 0.38, y);
        break;
    }

    canvas.drawPath(leftBrow, browPaint);
    canvas.drawPath(rightBrow, browPaint);
  }

  void _drawMouth(Canvas canvas, {required Offset center, required double r, required double time}) {
    final mouthPaint = Paint()
      ..color = const Color(0xFFBE123C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, r * 0.045)
      ..strokeCap = StrokeCap.round;

    final my = center.dy + r * 0.37;

    if (talking || mood == EinoMood.talking) {
      // Animated speaking mouth sync
      final openH = math.sin(time * math.pi * 2 * 3.5).abs() * (r * 0.12) + (r * 0.04);
      final mouthRect = Rect.fromCenter(center: Offset(center.dx, my), width: r * 0.22, height: openH);
      final openPaint = Paint()..color = const Color(0xFFE11D48);
      canvas.drawOval(mouthRect, openPaint);
      canvas.drawOval(mouthRect, mouthPaint);
      return;
    }

    final path = Path();
    switch (mood) {
      case EinoMood.happy:
        // Open wide joyful crescent smile
        final smileRect = Rect.fromCenter(center: Offset(center.dx, my), width: r * 0.26, height: r * 0.14);
        path.moveTo(smileRect.left, smileRect.top);
        path.quadraticBezierTo(center.dx, smileRect.bottom + r * 0.05, smileRect.right, smileRect.top);
        canvas.drawPath(path, Paint()..color = const Color(0xFFF43F5E));
        canvas.drawPath(path, mouthPaint);
        break;
      case EinoMood.proud:
        // Confident cat/feline upward smirk
        path.moveTo(center.dx - r * 0.14, my - r * 0.02);
        path.quadraticBezierTo(center.dx - r * 0.04, my + r * 0.04, center.dx, my);
        path.quadraticBezierTo(center.dx + r * 0.08, my + r * 0.06, center.dx + r * 0.16, my - r * 0.04);
        canvas.drawPath(path, mouthPaint);
        break;
      case EinoMood.pouting:
        // Cute wavy small pout
        path.moveTo(center.dx - r * 0.12, my);
        path.quadraticBezierTo(center.dx - r * 0.06, my + r * 0.03, center.dx, my);
        path.quadraticBezierTo(center.dx + r * 0.06, my + r * 0.03, center.dx + r * 0.12, my);
        canvas.drawPath(path, mouthPaint);
        break;
      case EinoMood.thinking:
        // Little 'o' dot mouth on side
        canvas.drawCircle(Offset(center.dx + r * 0.08, my), r * 0.045, Paint()..color = const Color(0xFFE11D48));
        break;
      case EinoMood.surprised:
        // Surprised round open 'O' mouth
        canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, my), width: r * 0.14, height: r * 0.18), Paint()..color = const Color(0xFFE11D48));
        canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, my), width: r * 0.14, height: r * 0.18), mouthPaint);
        break;
      case EinoMood.concerned:
        // Soft sad / downturned lip
        path.moveTo(center.dx - r * 0.14, my + r * 0.03);
        path.quadraticBezierTo(center.dx, my - r * 0.02, center.dx + r * 0.14, my + r * 0.03);
        canvas.drawPath(path, mouthPaint);
        break;
      case EinoMood.confused:
        // Tilted asymmetric mouth line
        path.moveTo(center.dx - r * 0.12, my + r * 0.02);
        path.lineTo(center.dx + r * 0.12, my - r * 0.02);
        canvas.drawPath(path, mouthPaint);
        break;
      default:
        // Calm gentle smile
        path.moveTo(center.dx - r * 0.13, my);
        path.quadraticBezierTo(center.dx, my + r * 0.05, center.dx + r * 0.13, my);
        canvas.drawPath(path, mouthPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _EinoAnimePainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.talking != talking ||
      oldDelegate.time != time ||
      oldDelegate.accent != accent ||
      oldDelegate.showAura != showAura;
}

