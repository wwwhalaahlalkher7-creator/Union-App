import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/shared/widgets/eino_route_transition.dart';

void main() {
  group('EinoRouteTransitionSignal', () {
    test('completes after the reverse reveal', () async {
      final completed = EinoRouteTransitionSignal.prepareForExit();

      EinoRouteTransitionSignal.completeExit();

      await expectLater(completed, completes);
    });

    test('ignores duplicate completion safely', () async {
      final completed = EinoRouteTransitionSignal.prepareForExit();

      EinoRouteTransitionSignal.completeExit();
      EinoRouteTransitionSignal.completeExit();

      await expectLater(completed, completes);
    });
  });
}
