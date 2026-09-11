import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] with a subtle scale + opacity response on press,
/// giving buttons and cards a tactile, "alive" feel instead of the
/// flat instant tap of a bare [InkWell].
///
/// Use it around anything tappable: cards, chips, icons, FABs.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.borderRadius,
    this.enableHaptics = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How much the widget shrinks while pressed (1.0 = no shrink).
  final double scaleDown;
  final BorderRadius? borderRadius;
  final bool enableHaptics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 220),
    lowerBound: 0,
    upperBound: 1,
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: widget.scaleDown,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onTapDown: reduceMotion ? null : _onTapDown,
      onTapUp: reduceMotion ? null : _onTapUp,
      onTapCancel: reduceMotion ? null : _onTapCancel,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.enableHaptics) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: reduceMotion
          ? widget.child
          : AnimatedBuilder(
              animation: _scale,
              builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
              child: widget.child,
            ),
    );
  }
}
