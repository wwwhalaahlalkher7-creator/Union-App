import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class TrinexSplashScreen extends StatefulWidget {
  const TrinexSplashScreen({super.key});
  @override State<TrinexSplashScreen> createState() => _TrinexSplashScreenState();
}

class _TrinexSplashScreenState extends State<TrinexSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final AnimationController _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  @override void dispose() { _controller.dispose(); _orbit.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ColoredBox(
    color: AppColors.navy,
    child: Stack(fit: StackFit.expand, children: [
      const _SplashCircuit(),
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
      Center(child: AnimatedBuilder(animation: _controller, builder: (context, child) => FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: const Interval(.05, .65, curve: Curves.easeOut)),
        child: ScaleTransition(scale: Tween(begin: .88, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)), child: child),
      ), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          Container(width: 188, height: 188, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withValues(alpha: .22)))),
          AnimatedBuilder(animation: _orbit, builder: (_, child) => Transform.rotate(angle: _orbit.value * math.pi * 2, child: child), child: CustomPaint(size: const Size(210, 210), painter: _OrbitPainter())),
          Container(width: 138, height: 138, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.navy, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 35)]), child: Image.asset('assets/icons/trinex_icon.png', fit: BoxFit.contain)),
        ]),
        const SizedBox(height: 24),
        const Text('TRINEX', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
        const SizedBox(height: 6),
        Text('هندسة • عمارة • تقنية', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        const Text('ابنِ مستقبلك من هنا', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        SizedBox(width: 150, child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(minHeight: 5, backgroundColor: Colors.white.withValues(alpha: .12), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)))),
      ]))),
      const PositionedDirectional(bottom: 28, start: 0, end: 0, child: Center(child: Text('Engineering • Architecture • Technology', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.4)))),
    ]),
  );
}

class _SplashCircuit extends StatelessWidget { const _SplashCircuit(); @override Widget build(BuildContext context) => CustomPaint(painter: _CircuitPainter()); }
class _CircuitPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.primary.withValues(alpha: .18)..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path()..moveTo(size.width*.02,size.height*.22)..lineTo(size.width*.18,size.height*.22)..lineTo(size.width*.28,size.height*.10)..lineTo(size.width*.28,size.height*.02)..moveTo(size.width*.98,size.height*.72)..lineTo(size.width*.80,size.height*.72)..lineTo(size.width*.72,size.height*.82)..lineTo(size.width*.72,size.height*.98);
    canvas.drawPath(path,p);
    for(final point in [Offset(size.width*.18,size.height*.22),Offset(size.width*.28,size.height*.10),Offset(size.width*.80,size.height*.72),Offset(size.width*.72,size.height*.82)]){canvas.drawCircle(point,4,p);}
  }
  @override bool shouldRepaint(covariant _CircuitPainter oldDelegate)=>false;
}
class _GridPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size){final p=Paint()..color=Colors.white.withValues(alpha:.025)..strokeWidth=1; const gap=48.0; for(double x=0;x<size.width;x+=gap){canvas.drawLine(Offset(x,0),Offset(x,size.height),p);} for(double y=0;y<size.height;y+=gap){canvas.drawLine(Offset(0,y),Offset(size.width,y),p);}}
  @override bool shouldRepaint(covariant _GridPainter oldDelegate)=>false;
}
class _OrbitPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size){final p=Paint()..color=AppColors.primary..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round; canvas.drawArc(Offset.zero&size,-.35,1.4,false,p); canvas.drawArc(Offset.zero&size,2.3,.8,false,p);}
  @override bool shouldRepaint(covariant _OrbitPainter oldDelegate)=>false;
}
