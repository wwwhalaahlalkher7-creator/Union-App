import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Shared surface primitive used throughout the app.
///
/// Interactive cards intentionally expose one clear tap target and provide
/// pressed feedback without introducing custom shadows or gradients.
class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
    this.semanticLabel,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final String? semanticLabel;
  final Color? borderColor;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: widget.margin ?? EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        side: BorderSide(
          color: widget.borderColor ?? context.colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(DesignTokens.space16),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return card;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed ? .985 : 1,
        duration: DesignTokens.fast,
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) setState(() => _pressed = value);
            },
            child: card,
          ),
        ),
      ),
    );
  }
}
