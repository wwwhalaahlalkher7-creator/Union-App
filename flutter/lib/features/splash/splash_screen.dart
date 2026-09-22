import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_version.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/storage/app_preferences.dart';
import '../../core/theme/design_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.startupFuture, super.key});
  final Future<void> startupFuture;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
    try {
      await widget.startupFuture;
    } catch (_) {
      // Preferences failure should not block opening the app.
    }
    if (!mounted || _navigated) return;

    // Reduced-motion mode should also skip the decorative minimum delay.
    // This keeps accessibility behavior consistent and makes widget tests
    // deterministic without waiting on a visual-only timer.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      final elapsed = DateTime.now().difference(started);
      final remaining = const Duration(milliseconds: 1200) - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    final prefs = AppPreferences();
    await prefs.init();
    if (!mounted) return;
    if (!prefs.onboardingCompleted) {
      context.go('/onboarding');
    } else {
      context.go('/media');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => CustomPaint(
                painter: _CircuitPainter(
                  progress: reduceMotion ? 1 : _controller.value,
                  accent: cs.primary,
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final value = reduceMotion ? 1.0 : Curves.easeOutCubic.transform(_controller.value);
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          padding: const EdgeInsets.all(16.56),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .06),
                            border: Border.all(color: cs.primary.withValues(alpha: .42)),
                            boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: .16), blurRadius: 38, spreadRadius: 4)],
                          ),
                          child: Image.asset('assets/icons/trinex_icon.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
                        ),
                        const SizedBox(height: 24),
                        Text(l10n.t('appName'), style: const TextStyle(color: Colors.white, fontSize: 27.6, fontWeight: FontWeight.w900, letterSpacing: 4)),
                        const SizedBox(height: 8),
                        Text(l10n.t('splashTagline'), style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(89.1),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: reduceMotion ? 1 : _controller.value.clamp(.05, .95),
                              backgroundColor: Colors.white.withValues(alpha: .12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('v${AppVersion.name}', style: TextStyle(color: Colors.white.withValues(alpha: .42), fontSize: 10.1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter({required this.progress, required this.accent});
  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accent.withValues(alpha: .14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dot = Paint()..color = accent.withValues(alpha: .35);
    final paths = <List<Offset>>[
      [Offset(size.width * .08, size.height * .22), Offset(size.width * .25, size.height * .22), Offset(size.width * .31, size.height * .28)],
      [Offset(size.width * .92, size.height * .32), Offset(size.width * .73, size.height * .32), Offset(size.width * .68, size.height * .27)],
      [Offset(size.width * .12, size.height * .76), Offset(size.width * .28, size.height * .76), Offset(size.width * .34, size.height * .70)],
      [Offset(size.width * .88, size.height * .72), Offset(size.width * .72, size.height * .72), Offset(size.width * .66, size.height * .66)],
    ];
    for (final points in paths) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final metric = path.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * progress), p);
      for (final point in points) {
        canvas.drawCircle(point, 3.2, dot);
      }
    }
    final glow = Paint()..shader = RadialGradient(colors: [accent.withValues(alpha: .08), Colors.transparent]).createShader(Rect.fromCircle(center: size.center(Offset.zero), radius: math.min(size.width, size.height) * .55));
    canvas.drawCircle(size.center(Offset.zero), math.min(size.width, size.height) * .55, glow);
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.accent != accent;
}
