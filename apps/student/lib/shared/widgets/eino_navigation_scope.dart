import 'package:flutter/widgets.dart';

typedef EinoNavigationHandler = Future<void> Function({
  BuildContext? sourceContext,
  required String source,
});

/// Gives pages inside TrinexShell access to the same animated Eino launcher
/// used by the floating assistant button.
class EinoNavigationScope extends InheritedWidget {
  const EinoNavigationScope({
    required this.onOpen,
    required super.child,
    super.key,
  });

  final EinoNavigationHandler onOpen;

  static EinoNavigationScope? maybeOf(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<EinoNavigationScope>()
          ?.widget as EinoNavigationScope?;

  Future<void> open({BuildContext? sourceContext, required String source}) =>
      onOpen(sourceContext: sourceContext, source: source);

  @override
  bool updateShouldNotify(EinoNavigationScope oldWidget) =>
      onOpen != oldWidget.onOpen;
}
