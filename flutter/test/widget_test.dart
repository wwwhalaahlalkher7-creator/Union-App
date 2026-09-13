import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leo_association/app/app.dart';
import 'package:leo_association/features/home/home_screen.dart';

void main() {
  testWidgets('TRINEX app starts on home', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: LeoAssociationApp(
          enableStartupUpdateCheck: false,
          startupFutureOverride: Future<void>.value(),
        ),
      ),
    );

    // The home screen now has a few intentionally infinite/looping
    // animations (Eino's idle breathing, the banner glow, the FAB pulse),
    // so `pumpAndSettle()` never settles and times out. Pump a handful of
    // fixed frames instead — enough for the splash bootstrap transition and
    // async preference loading to finish, without waiting for looping animations.
    // Reduced-motion mode skips the splash's visual-only minimum delay.
    // Startup is injected as an already-completed future so this test
    // verifies routing/rendering rather than platform preference I/O.
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
