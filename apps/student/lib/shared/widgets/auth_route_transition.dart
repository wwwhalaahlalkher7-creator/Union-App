import 'package:flutter/material.dart';

/// A split-panel wipe for login/register routes. The auth forms remain separate,
/// keeping validation, session handling and registration side effects untouched.
class AuthRouteTransition extends StatelessWidget {
  const AuthRouteTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    // Split-panel wipes need room to breathe. On phones they can cover the
    // form, feel overly theatrical, and compete with the keyboard/scrolling.
    // Use a short directional fade/slide on compact layouts instead.
    if (width < 600 || size.height < 520) {
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      final slideDirection = isRtl ? -1.0 : 1.0;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.035 * slideDirection, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    }
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final direction = isRtl ? -1.0 : 1.0;
    final colors = Theme.of(context).colorScheme;
    final rawProgress = animation.value.clamp(0.0, 1.0).toDouble();
    final progress = Curves.easeInOutCubic.transform(rawProgress);
    final leadingWidth = width * 0.54;
    final trailingWidth = width - leadingWidth;

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: Offset(direction * 0.035 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        ),
        if (progress < 1)
          IgnorePointer(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: leadingWidth,
                    child: Transform.translate(
                      offset: Offset(-direction * leadingWidth * progress, 0),
                      child: Container(
                        color: colors.primary,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: (1 - progress).clamp(0.0, 1.0).toDouble(),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.onPrimary,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    bottom: 0,
                    width: trailingWidth,
                    child: Transform.translate(
                      offset: Offset(direction * trailingWidth * progress, 0),
                      child: Container(
                        color: colors.primaryContainer,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: (1 - progress).clamp(0.0, 1.0).toDouble(),
                          child: Icon(
                            Icons.school_outlined,
                            color: colors.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
