#!/usr/bin/env python3
"""Static safety checks for Eino's animated floating-orb lifecycle."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
orb = (ROOT / 'apps/student/lib/features/eino/eino_orb.dart').read_text()
face = (ROOT / 'apps/student/lib/features/eino/eino_face.dart').read_text()
shell = (ROOT / 'apps/student/lib/shared/widgets/trinex_shell.dart').read_text()
screen = (ROOT / 'apps/student/lib/features/eino/eino_screen.dart').read_text()
home = (ROOT / 'apps/student/lib/features/home/home_screen.dart').read_text()
tests = (ROOT / 'apps/student/test/eino_orb_test.dart').read_text()

checks = {
    'inactivity threshold defaults to thirty seconds': 'Duration(seconds: 30)' in face,
    'sleep retains low-speed animation rather than stopping': '_controller.duration = const Duration(milliseconds: 1250)' in face and '_scheduleIdlePulse()' in face,
    'tap wake animation gets time to render before chat opens': 'Duration(milliseconds: 180)' in shell and shell.find('await Future<void>.delayed(const Duration(milliseconds: 180))') < shell.find('EinoMotionSession.markChatOpened()'),
    'chat route closure creates a one-shot return cue': 'class EinoMotionSession' in orb and 'markChatClosed()' in screen and 'consumeReturnAnimation()' in shell,
    'hidden floating orb suspends while chat is open and resumes afterward': 'EinoMotionSession.changes.addListener(_handleChatSessionChange)' in face and 'if (EinoMotionSession.chatOpen)' in face and 'suspendWhileChatOpen: true' in shell and '_controller.stop(canceled: false)' in face,
    'shell restores return animation for all Eino routes': '_playPendingEinoReturn()' in shell and "oldWidget.location.startsWith('/eino')" in shell and 'returning: true' in shell,
    'all identified Eino entry points mark chat state': 'EinoMotionSession.markChatOpened()' in shell and 'EinoMotionSession.markChatOpened()' in screen and "context.push('/eino?from=home')" in home,
    'widget tests cover chat suspension and return animation': 'background orb pauses during chat and resumes on return' in tests and 'EinoMotionSession.markChatOpened()' in tests and 'EinoMotionSession.markChatClosed()' in tests,
}
for name, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ' ' + name)
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit('Eino orb motion checks failed: ' + ', '.join(failed))
print(f'EINO ORB MOTION CHECK PASSED: {len(checks)} checks')
