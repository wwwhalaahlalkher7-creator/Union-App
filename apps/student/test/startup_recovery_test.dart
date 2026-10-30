import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:leo_association/core/localization/app_localizations.dart';
import 'package:leo_association/features/splash/splash_screen.dart';

void main() {
  testWidgets('startup failure shows retry and recovers without opening a broken route',
      (tester) async {
    var retryCalls = 0;
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => SplashScreen(
            startupFuture: Future<void>.delayed(
              Duration.zero,
              () => throw StateError('simulated startup error'),
            ),
            onRetryStartup: () async {
              retryCalls++;
            },
            onboardingCompleted: () => false,
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('onboarding-reached')),
        ),
      ],
    );
    addTearDown(router.dispose);

    // Disable animations so this test verifies startup/retry routing rather
    // than depending on wall-clock animation duration in CI.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تجهيز التطبيق'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('onboarding-reached'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(retryCalls, 1);
    expect(find.text('onboarding-reached'), findsOneWidget);
  });
}
