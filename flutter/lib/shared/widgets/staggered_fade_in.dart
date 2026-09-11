import 'package:flutter/material.dart';

/// Animates [children] in one by one with a soft fade + upward slide,
/// so a screen's content feels like it's arriving rather than just
/// appearing. Drop this around any list of widgets you'd otherwise
/// place directly inside a Column/SliverList.
class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({
    required this.children,
    this.delay = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
    this.offset = 18,
    super.key,
  });

  final List<Widget> children;

  /// Extra delay added per child index, creating the "stagger".
  final Duration delay;
  final Duration duration;

  /// Vertical distance (px) each child travels while fading in.
  final double offset;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final total = widget.duration +
        widget.delay * (widget.children.isEmpty ? 0 : widget.children.length - 1);
    _controller = AnimationController(vsync: this, duration: total)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.children,
      );
    }
    final totalMs = _controller.duration!.inMilliseconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _buildItem(i, totalMs),
      ],
    );
  }

  Widget _buildItem(int index, int totalMs) {
    final startMs = (widget.delay.inMilliseconds * index).clamp(0, totalMs);
    final endMs = (startMs + widget.duration.inMilliseconds).clamp(0, totalMs);
    final interval = Interval(
      totalMs == 0 ? 0 : startMs / totalMs,
      totalMs == 0 ? 1 : endMs / totalMs,
      curve: Curves.easeOutCubic,
    );
    final animation = CurvedAnimation(parent: _controller, curve: interval);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - animation.value)),
          child: child,
        ),
      ),
      child: widget.children[index],
    );
  }
}
