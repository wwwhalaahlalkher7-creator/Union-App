import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leo_association/app/app.dart';
import 'package:leo_association/features/home/home_screen.dart';

void main() {
  testWidgets('TRINEX app starts on home', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: LeoAssociationApp(enableStartupUpdateCheck: false),
      ),
    );

    // The home screen now has a few intentionally infinite/looping
    // animations (Eino's idle breathing, the banner glow, the FAB pulse),
    // so `pumpAndSettle()` never settles and times out. Pump a handful of
    // fixed frames instead — enough for the splash bootstrap transition and
    // async preference loading to finish, without waiting for looping animations.
    // Reduced-motion mode skips the splash's visual-only minimum delay.
    // Pump enough frames for preferences, routing, and the first home build.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
