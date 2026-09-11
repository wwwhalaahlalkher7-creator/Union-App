import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class AppSection extends StatelessWidget {
  const AppSection({required this.title, this.subtitle, this.action, required this.child, super.key});

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: DesignTokens.space4),
              Text(subtitle!, style: text.bodySmall),
            ],
          ])),
          if (action != null) action!,
        ]),
        const SizedBox(height: DesignTokens.space12),
        child,
      ],
    );
  }
}
