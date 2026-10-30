import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leo_association/core/localization/app_localizations.dart';
import 'package:leo_association/core/storage/app_preferences.dart';
import 'package:leo_association/features/onboarding/guided_tour_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('guided tour pending and completion state is isolated per student', () async {
    final preferences = AppPreferences();
    await preferences.init();

    await preferences.setLearningModePendingFor('24-001', true);
    expect(preferences.learningModePendingFor('24-001'), isTrue);
    expect(preferences.learningModePendingFor('24-002'), isFalse);

    await preferences.setLearningModeCompletedFor('24-001', true);
    await preferences.setLearningModePendingFor('24-001', false);
    expect(preferences.learningModeCompletedFor('24-001'), isTrue);
    expect(preferences.learningModePendingFor('24-001'), isFalse);
    expect(preferences.learningModeCompletedFor('24-002'), isFalse);
  });

  testWidgets('guided tour spotlights the real home navigation anchor', (tester) async {
    var tapped = false;
    var skipped = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              key: guidedTourHomeNavKey,
              width: 72,
              height: 48,
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
          GuidedTourOverlay(
            stepIndex: 0,
            onTargetTap: () => tapped = true,
            onSkip: () => skipped = true,
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GuidedTourOverlay), findsOneWidget);
    expect(guidedTourHomeNavKey.currentContext, isNotNull);
    await tester.tapAt(tester.getRect(find.byKey(guidedTourHomeNavKey)).center);
    await tester.pump();
    expect(tapped, isTrue);
    expect(skipped, isFalse);
  });
}
