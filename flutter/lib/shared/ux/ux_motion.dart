import 'package:flutter/material.dart';

class UxMotion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 220);
  static const page = Duration(milliseconds: 300);
  static Curve get enter => Curves.easeOutCubic;
  static Curve get exit => Curves.easeInCubic;
}

class UxPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  const UxPressScale({super.key, required this.child, this.onTap, this.pressedScale = .985});
  @override State<UxPressScale> createState() => _UxPressScaleState();
}
class _UxPressScaleState extends State<UxPressScale> {
  bool _pressed = false;
  @override Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null ? null : (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      child: AnimatedScale(scale: _pressed ? widget.pressedScale : 1, duration: UxMotion.fast, curve: UxMotion.enter, child: widget.child),
    ),
  );
}
