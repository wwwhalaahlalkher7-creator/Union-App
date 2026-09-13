import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_version.dart';

/// TRINEX branded startup screen inspired directly by the approved identity
/// board: navy canvas, architectural mark, orange circuit accents and a calm
/// loading indicator.
class TrinexSplashScreen extends StatefulWidget {
  const TrinexSplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<TrinexSplashScreen> createState() => _TrinexSplashScreenState();
}

class _TrinexSplashScreenState extends State<TrinexSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _circuit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _circuit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B45),
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _circuit]),
        builder: (context, child) {
          final fade = Curves.easeOutCubic.transform(_intro.value);
          final slide = (1 - fade) * 18;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _SplashBackground(),
              IgnorePointer(
                child: CustomPaint(
                  painter: _CircuitPainter(progress: _circuit.value),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Transform.translate(
                      offset: Offset(0, slide),
                      child: Opacity(
                        opacity: fade,
                        child: Image.asset(
                          'assets/images/trinex_splash_logo.png',
                          width: 310,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Transform.translate(
                      offset: Offset(0, slide * .65),
                      child: Opacity(
                        opacity: fade,
                        child: const Column(
                          children: [
                            Text(
                              'منصة طلاب الهندسة والعمارة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .15,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'تعلم • طوّر • ابنِ المستقبل',
                              style: TextStyle(
                                color: Color(0xFFAFC0D0),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: fade,
                      child: const _LoadingBar(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'TRINEX  •  ${AppVersion.full}',
                      style: const TextStyle(
                        color: Color(0xFF8EA7BA),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.15),
          radius: 1.15,
          colors: [Color(0xFF173C5A), Color(0xFF0D2B45), Color(0xFF081D30)],
          stops: [0, .58, 1],
        ),
      ),
      child: CustomPaint(painter: _ArchitecturePainter()),
    );
  }
}

class _ArchitecturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF4E6B8A).withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final horizon = size.height * .79;
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), line);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (.12 + i * .13);
      canvas.drawLine(Offset(x, horizon), Offset(x + size.width * .06, size.height), line);
    }

    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x33F47B20), Color(0x00F47B20)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .82, size.height * .18),
        radius: size.width * .42,
      ));
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .18),
      size.width * .42,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchitecturePainter oldDelegate) => false;
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFF47B20).withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * .95, size.height * .02)
      ..lineTo(size.width * .84, size.height * .13)
      ..lineTo(size.width * .84, size.height * .22)
      ..lineTo(size.width * .75, size.height * .31)
      ..lineTo(size.width * .75, size.height * .40)
      ..lineTo(size.width * .65, size.height * .50);
    canvas.drawPath(path, p);

    final path2 = Path()
      ..moveTo(size.width * .02, size.height * .92)
      ..lineTo(size.width * .13, size.height * .81)
      ..lineTo(size.width * .13, size.height * .73)
      ..lineTo(size.width * .23, size.height * .63);
    canvas.drawPath(path2, p..color = const Color(0xFFF47B20).withValues(alpha: .35));

    final points = <Offset>[
      Offset(size.width * .84, size.height * .13),
      Offset(size.width * .75, size.height * .31),
      Offset(size.width * .75, size.height * .40),
      Offset(size.width * .13, size.height * .81),
    ];
    final pulse = .72 + math.sin(progress * math.pi * 2) * .28;
    for (final point in points) {
      canvas.drawCircle(point, 4.5, p..style = PaintingStyle.stroke);
      canvas.drawCircle(
        point,
        2.2 * pulse,
        p..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 4, color: const Color(0xFF31516A)),
                FractionallySizedBox(
                  widthFactor: .38 + (_controller.value * .22),
                  child: Container(height: 4, color: const Color(0xFFF47B20)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
