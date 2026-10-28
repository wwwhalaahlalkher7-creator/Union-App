import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/features/eino/eino_orb.dart';

void main() {
  testWidgets('Eino orb enters reduced-motion sleep after inactivity', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EinoOrb(size: 64, accent: Colors.amber),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Eino assistant active'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.bySemanticsLabel('Eino assistant sleeping'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  test('Eino return animation waits for chat disposal and is consumed once', () {
    EinoMotionSession.markChatOpened();
    expect(EinoMotionSession.consumeReturnAnimation(), isFalse);
    EinoMotionSession.markChatClosed();
    expect(EinoMotionSession.consumeReturnAnimation(), isTrue);
    expect(EinoMotionSession.consumeReturnAnimation(), isFalse);
  });

  testWidgets('background orb pauses during chat and resumes on return', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EinoOrb(
                size: 64,
                accent: Colors.amber,
                suspendWhileChatOpen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      EinoMotionSession.markChatOpened();
      await tester.pump();
      expect(EinoMotionSession.chatOpen, isTrue);
      EinoMotionSession.markChatClosed();
      EinoMotionSession.consumeReturnAnimation();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(EinoMotionSession.chatOpen, isFalse);
      expect(
        find.descendant(
          of: find.byType(EinoOrb),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Eino assistant active'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Eino orb supports the chat-return motion state', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EinoOrb(
                size: 64,
                accent: Colors.amber,
                returningFromChat: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Eino assistant active'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EinoOrb),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('tapping the Eino orb wakes it and invokes its action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EinoOrb(
                size: 64,
                accent: Colors.amber,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 31));
      expect(find.bySemanticsLabel('Eino assistant sleeping'), findsOneWidget);
      await tester.tap(find.byType(EinoOrb));
      await tester.pump();
      expect(tapped, isTrue);
      expect(find.bySemanticsLabel('Eino assistant active'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
