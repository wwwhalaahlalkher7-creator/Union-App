import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leo_association/core/localization/app_localizations.dart';
import 'package:leo_association/core/storage/app_preferences.dart';
import 'package:leo_association/features/onboarding/study_tutorial_overlay.dart';
import 'package:leo_association/shared/widgets/trinex_shell.dart';

Widget _shellApp(String location) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: TrinexShell(
        key: const ValueKey('shell'),
        location: location,
        child: Center(child: Text(location)),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'study_tutorial_pending': false,
    });
  });

  testWidgets('shows the tour after a successful registration flag is pending',
      (tester) async {
    final preferences = AppPreferences();
    await preferences.init();
    await preferences.setStudyTutorialPending(true);

    await tester.pumpWidget(_shellApp('/media'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(StudyTutorialOverlay), findsOneWidget);
    expect(preferences.studyTutorialPending, isFalse);
  });

  testWidgets('re-checks the pending tour when the shell route changes',
      (tester) async {
    await tester.pumpWidget(_shellApp('/materials'));
    await tester.pump();
    expect(find.byType(StudyTutorialOverlay), findsNothing);

    final preferences = AppPreferences();
    await preferences.init();
    await preferences.setStudyTutorialPending(true);

    // Registration/session transitions can set this after the shell's first
    // frame; the transition back to a top-level shell page must not miss it.
    await tester.pumpWidget(_shellApp('/media'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(StudyTutorialOverlay), findsOneWidget);
    expect(preferences.studyTutorialPending, isFalse);
  });

  testWidgets('spotlight anchors resolve to the real profile, materials and Eino controls',
      (tester) async {
    final preferences = AppPreferences();
    await preferences.init();
    await preferences.setStudyTutorialPending(true);

    await tester.pumpWidget(_shellApp('/media'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(StudyTutorialOverlay), findsOneWidget);
    expect(StudyTutorialTargets.profile.currentContext, isNotNull);
    expect(StudyTutorialTargets.materials.currentContext, isNotNull);
    expect(StudyTutorialTargets.eino.currentContext, isNotNull);
  });

  testWidgets('tour never appears on an unrelated route and preserves pending flag',
      (tester) async {
    final preferences = AppPreferences();
    await preferences.init();
    await preferences.setStudyTutorialPending(true);

    await tester.pumpWidget(_shellApp('/materials'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(StudyTutorialOverlay), findsNothing);
    expect(preferences.studyTutorialPending, isTrue);
  });
}
