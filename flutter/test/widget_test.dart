import 'package:flutter_test/flutter_test.dart';

import 'package:leo_association/app/app.dart';
import 'package:leo_association/features/home/home_screen.dart';

void main() {
  testWidgets('Leo Association app starts on home', (tester) async {
    await tester.pumpWidget(const LeoAssociationApp());

    // The home screen now has a few intentionally infinite/looping
    // animations (Eino's idle breathing, the banner glow, the FAB pulse),
    // so `pumpAndSettle()` never settles and times out. Pump a handful of
    // fixed frames instead — enough for one-shot entrance animations and
    // async preference loading to finish, without waiting for the loops.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
