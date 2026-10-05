import 'package:flutter/material.dart';

enum ActionFeedbackType { like, unlike, comment, reply, success }

class ActionFeedback {
  ActionFeedback._();

  static void show(
    BuildContext context, {
    required ActionFeedbackType type,
    Duration duration = const Duration(milliseconds: 850),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final theme = Theme.of(context);
    final icon = switch (type) {
      ActionFeedbackType.like => Icons.thumb_up_rounded,
      ActionFeedbackType.unlike => Icons.thumb_up_off_alt_rounded,
      ActionFeedbackType.comment => Icons.chat_bubble_rounded,
      ActionFeedbackType.reply => Icons.reply_rounded,
      ActionFeedbackType.success => Icons.check_circle_rounded,
    };
    final entry = OverlayEntry(
      builder: (context) => _ActionFeedbackOverlay(icon: icon, color: theme.colorScheme.primary, duration: duration),
    );
    overlay.insert(entry);
    Future<void>.delayed(duration + const Duration(milliseconds: 80), () {
      entry.remove();
    });
  }
}

class _ActionFeedbackOverlay extends StatefulWidget {
  const _ActionFeedbackOverlay({required this.icon, required this.color, required this.duration});
  final IconData icon;
  final Color color;
  final Duration duration;

  @override
  State<_ActionFeedbackOverlay> createState() => _ActionFeedbackOverlayState();
}

class _ActionFeedbackOverlayState extends State<_ActionFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: .55, end: 1.18).chain(CurveTween(curve: Curves.easeOutBack)), weight: 48),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: .98).chain(CurveTween(curve: Curves.easeOut)), weight: 28),
    TweenSequenceItem(tween: Tween(begin: .98, end: 1.0), weight: 24),
  ]).animate(_controller);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 24),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: .18),
                  blurRadius: 24,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(widget.icon, size: 38, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
