import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          margin: const EdgeInsetsDirectional.only(end: DesignTokens.space8),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            label: Text(actionLabel!),
            icon: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: 12,
            ),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}
