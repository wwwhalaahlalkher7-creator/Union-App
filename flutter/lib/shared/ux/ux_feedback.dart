import 'package:flutter/material.dart';
class UxFeedback {
  static void success(BuildContext context, String message) => _show(context, message, Icons.check_circle_outline);
  static void error(BuildContext context, String message) => _show(context, message, Icons.error_outline);
  static void info(BuildContext context, String message) => _show(context, message, Icons.info_outline);
  static void _show(BuildContext context, String message, IconData icon) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3),
      content: Row(children: [Icon(icon, size: 20), const SizedBox(width: 10), Expanded(child: Text(message))]),
    ));
  }
}
