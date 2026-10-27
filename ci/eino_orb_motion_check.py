#!/usr/bin/env python3
"""Static safety checks for the Eino orb's motion lifecycle."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
orb = (ROOT / 'apps/student/lib/features/eino/eino_orb.dart').read_text()
shell = (ROOT / 'apps/student/lib/shared/widgets/trinex_shell.dart').read_text()
home = (ROOT / 'apps/student/lib/features/home/home_screen.dart').read_text()
tests = (ROOT / 'apps/student/test/eino_orb_test.dart').read_text()

checks = {
    'inactivity threshold defaults to thirty seconds': 'Duration(seconds: 30)' in orb,
    'sleep retains low-speed animation rather than stopping': '_motion.duration = Duration(' in orb and 'milliseconds: _sleeping ? 12000' in orb and 'if (!_motion.isAnimating) _motion.repeat()' in orb,
    'tap wakes orb and temporarily boosts its speed': '_boostMotion(returning: false)' in orb and '(_boosted ? 520 : 2300)' in orb,
    'organic liquid contour animates with phase': '_liquidPath(' in orb and 'math.sin(angle * 2.0 + phase * 0.86)' in orb,
    'internal light particles move independently': 'for (var i = 0; i < 4; i++)' in orb and 'particlePhase' in orb,
    'return transition waits until the chat route closes': 'class EinoMotionSession' in orb and 'markChatClosed()' in (ROOT / 'apps/student/lib/features/eino/eino_screen.dart').read_text() and '_returnAnimationPending' in orb and 'consumeReturnAnimation()' in shell and 'returningFromChat: returningFromChat' in shell,
    'hidden orb suspends during chat and resumes with return motion': 'EinoMotionSession.changes.addListener(_handleChatSessionChange)' in orb and 'if (EinoMotionSession.chatOpen)' in orb and 'suspendWhileChatOpen: true' in shell and '_motion.stop();' in orb and 'background orb pauses during chat and resumes on return' in tests,
    'floating button listens for route return so return cue is not dropped': 'class _EinoFloatingButtonState extends State<EinoFloatingButton>' in shell and 'EinoMotionSession.changes.addListener(_handleMotionSessionChange)' in shell,
    'tap wake animation gets time to render before chat opens': 'Duration(milliseconds: 180)' in shell and shell.find('await Future<void>.delayed(const Duration(milliseconds: 180))') < shell.find('EinoMotionSession.markChatOpened()', shell.find('Future<void> _openChat')) and "context.push('/eino?from=shell')" in shell,
    'all identified Eino entry points mark the chat session': 'EinoMotionSession.markChatOpened()' in shell and 'EinoMotionSession.markChatOpened()' in home,
    'widget tests cover sleep, wake and return animation': all(term in tests for term in ['sleep after inactivity', 'wakes it and invokes', 'chat-return motion state']) and 'waits for chat disposal and is consumed once' in tests,
}
for name, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ' ' + name)
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit('Eino orb motion checks failed: ' + ', '.join(failed))
print(f'EINO ORB MOTION CHECK PASSED: {len(checks)} checks')
