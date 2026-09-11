import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.padding, this.onTap, this.margin, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: margin ?? EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DesignTokens.space16),
        child: child,
      ),
    );
    if (onTap == null) return card;
    return Semantics(button: true, child: InkWell(onTap: onTap, child: card));
  }
}
