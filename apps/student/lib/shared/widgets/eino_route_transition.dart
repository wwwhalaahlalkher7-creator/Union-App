import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class EinoRouteTransitionSignal {
  EinoRouteTransitionSignal._();

  static Completer<void>? _exitCompleter;

  static Future<void> prepareForExit() {
    _exitCompleter = Completer<void>();
    return _exitCompleter!.future;
  }

  static void completeExit() {
    final completer = _exitCompleter;
    _exitCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}

/// A circular page reveal that expands from Eino's point of invocation.
/// The route is non-opaque during the transition, so the previous page remains
/// visible outside the expanding circle. Popping the route naturally reverses
/// the same reveal back toward the original source.
class EinoCircularRouteTransition extends StatefulWidget {
  const EinoCircularRouteTransition({
    required this.animation,
    required this.child,
    required this.origin,
    this.onReverseCompleted,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;
  final Offset? origin;
  final VoidCallback? onReverseCompleted;

  @override
  State<EinoCircularRouteTransition> createState() =>
      _EinoCircularRouteTransitionState();
}

class _EinoCircularRouteTransitionState
    extends State<EinoCircularRouteTransition> {
  late CurvedAnimation _curved;
  bool _hasEntered = false;
  bool _exitReported = false;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.animation.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(covariant EinoCircularRouteTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      _curved.dispose();
      _curved = CurvedAnimation(
        parent: widget.animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      widget.animation.addStatusListener(_handleStatus);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse ||
        status == AnimationStatus.completed) {
      _hasEntered = true;
    }
    if (status == AnimationStatus.dismissed && _hasEntered && !_exitReported) {
      _exitReported = true;
      widget.onReverseCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    final size = MediaQuery.sizeOf(context);
    final center = widget.origin ?? Offset(size.width / 2, size.height / 2);

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final progress = _curved.value.clamp(0.0, 1.0).toDouble();
        final radius = _maximumRadius(size, center) * progress + 1.5;
        return ClipPath(
          clipBehavior: Clip.antiAlias,
          clipper: _EinoCircularClipper(center: center, radius: radius),
          child: widget.child,
        );
      },
    );
  }

  double _maximumRadius(Size size, Offset center) {
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    return corners
        .map((corner) => (corner - center).distance)
        .fold<double>(0, (current, next) => math.max(current, next).toDouble());
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    _curved.dispose();
    super.dispose();
  }
}

class _EinoCircularClipper extends CustomClipper<Path> {
  const _EinoCircularClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _EinoCircularClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}
