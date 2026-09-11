import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class AppButton extends StatelessWidget {
  const AppButton({required this.label, required this.onPressed, this.icon, this.secondary = false, super.key});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final button = secondary
        ? OutlinedButton.icon(onPressed: onPressed, icon: icon == null ? const SizedBox.shrink() : Icon(icon), label: Text(label))
        : FilledButton.icon(onPressed: onPressed, icon: icon == null ? const SizedBox.shrink() : Icon(icon), label: Text(label));
    return SizedBox(height: DesignTokens.controlHeight, child: button);
  }
}
