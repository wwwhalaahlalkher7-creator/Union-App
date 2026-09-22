import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/localization/app_localizations.dart';

class TrinexLogo extends StatelessWidget {
  const TrinexLogo({super.key, this.width = 190});

  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TrinexMark(size: 38, radius: 12),
          const SizedBox(width: 9),
          Text(AppLocalizations.of(context).t('appName'), style: TextStyle(fontSize: width * .105, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurface)),
        ],
      );
    }
    return Image.asset('assets/images/trinex_logo.png', width: width, fit: BoxFit.contain, filterQuality: FilterQuality.high);
  }
}

class TrinexMark extends StatelessWidget {
  const TrinexMark({super.key, this.size = 52, this.radius = 16});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.76),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: .16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2.7),
        child: Image.asset('assets/icons/trinex_icon.png', fit: BoxFit.cover),
      ),
    );
  }
}

class CircuitDecoration extends StatelessWidget {
  const CircuitDecoration({super.key, this.opacity = .16});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CircuitPainter(opacity, Theme.of(context).colorScheme.primary),
        size: const Size(160, 160),
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter(this.opacity, this.color);
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .05)
      ..lineTo(size.width * .18, size.height * .34)
      ..lineTo(size.width * .42, size.height * .58)
      ..lineTo(size.width * .42, size.height * .9)
      ..moveTo(size.width * .42, size.height * .58)
      ..lineTo(size.width * .72, size.height * .58)
      ..lineTo(size.width * .88, size.height * .74);
    canvas.drawPath(path, orange);
    for (final point in [
      Offset(size.width * .18, size.height * .34),
      Offset(size.width * .42, size.height * .58),
      Offset(size.width * .42, size.height * .9),
      Offset(size.width * .72, size.height * .58),
      Offset(size.width * .88, size.height * .74),
    ]) {
      canvas.drawCircle(point, 4, orange);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => oldDelegate.opacity != opacity;
}
