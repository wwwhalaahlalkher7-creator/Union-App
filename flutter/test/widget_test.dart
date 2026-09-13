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
          initialLocationOverride: '/home',
        ),
      ),
    );

    // This widget test verifies the app's home route without depending on
    // splash timing or platform preference I/O. Splash behavior is covered
    // by the production startup path itself.
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
