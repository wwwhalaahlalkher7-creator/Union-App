import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/features/eino/eino_face.dart';

void main() {
  group('Eino glass orb', () {
    testWidgets('renders a compact floating orb with accessible semantics', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: EinoOrb(size: 56))),
      ));

      expect(find.byType(EinoOrb), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      expect(find.bySemanticsLabel('Eino assistant'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('supports listening, thinking, responding and error states', (tester) async {
      const states = <({EinoMood mood, bool talking, String label})>[
        (mood: EinoMood.calm, talking: false, label: 'Eino assistant'),
        (mood: EinoMood.thinking, talking: false, label: 'Eino thinking'),
        (mood: EinoMood.talking, talking: true, label: 'Eino responding'),
        (mood: EinoMood.listening, talking: false, label: 'Eino listening'),
        (mood: EinoMood.reading, talking: false, label: 'Eino reading response aloud'),
        (mood: EinoMood.success, talking: false, label: 'Eino response complete'),
        (mood: EinoMood.concerned, talking: false, label: 'Eino connection issue'),
      ];

      for (final state in states) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: EinoOrb(
                key: ValueKey(state.label),
                size: 92,
                mood: state.mood,
                talking: state.talking,
              ),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.bySemanticsLabel(state.label), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });


    testWidgets('all declared moods render without errors', (tester) async {
      for (final mood in EinoMood.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(child: EinoOrb(key: ValueKey(mood), size: 64, mood: mood)),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.byType(EinoOrb), findsOneWidget, reason: 'Mood $mood should render');
        expect(tester.takeException(), isNull, reason: 'Mood $mood should not throw');
      }
    });

    testWidgets('transition boost animates the orb without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: EinoOrb(size: 92, motionBoost: 0))),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: EinoOrb(size: 92, motionBoost: 1))),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EinoOrb), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('respects reduced-motion preference and renders at small sizes', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: EinoOrb(size: 32))),
        ),
      ));
      await tester.pump();
      expect(find.byType(EinoOrb), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
