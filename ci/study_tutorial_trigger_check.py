#!/usr/bin/env python3
"""Guard the one-time post-registration in-app tutorial trigger."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
register = (ROOT / 'apps/student/lib/features/auth/register_screen.dart').read_text()
login = (ROOT / 'apps/student/lib/features/auth/login_screen.dart').read_text()
onboarding = (ROOT / 'apps/student/lib/features/onboarding/onboarding_screen.dart').read_text()
shell = (ROOT / 'apps/student/lib/shared/widgets/trinex_shell.dart').read_text()
test = (ROOT / 'apps/student/test/study_tutorial_trigger_test.dart').read_text()
overlay = (ROOT / 'apps/student/lib/features/onboarding/study_tutorial_overlay.dart').read_text()

checks = {
    'registration sets the pending one-shot flag after saving the session': register.find('await _storage?.saveSession(result);') >= 0 and register.find('await prefs.setStudyTutorialPending(true)') > register.find('await _storage?.saveSession(result);'),
    'ordinary login never triggers the registration tutorial': 'setStudyTutorialPending(true)' not in login and 'await prefs.setStudyTutorialPending(false)' in login,
    'guest continuation clears a stale registration-only trigger': "path == '/media'" in onboarding and 'await prefs.setStudyTutorialPending(false)' in onboarding,
    'tutorial is rechecked on route change': 'oldWidget.location != widget.location) _scheduleStudyTutorialCheck()' in shell,
    'tutorial is limited to safe top-level shell pages': "widget.location != '/media' && widget.location != '/student'" in shell,
    'pending flag is restored if dialog presentation fails': 'if (consumed && !displayed && preferences != null)' in shell,
    'the one-shot flag is consumed to prevent duplicates': 'await preferences.setStudyTutorialPending(false)' in shell and '_tutorialDialogOpen' in shell,
    'tutorial is a distinct in-app animated overlay': 'class StudyTutorialOverlay' in overlay and 'AnimatedBuilder' in overlay and '_TutorialSpotlightPainter' in overlay,
    'tutorial spotlights the real profile/materials/Eino controls': all(term in overlay for term in ['StudyTutorialTargets.profile', 'StudyTutorialTargets.materials', 'StudyTutorialTargets.eino', '_measureTarget', 'PathFillType.evenOdd']) and 'key: StudyTutorialTargets.profile' in shell and 'key: StudyTutorialTargets.materials' in shell and 'key: StudyTutorialTargets.eino' in shell and 'barrierColor: Colors.transparent' in shell,
    'widget tests cover initial, delayed and ineligible route triggers': all(term in test for term in ['after a successful registration', 'when the shell route changes', 'unrelated route']),
}
for name, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ' ' + name)
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit('Study tutorial trigger checks failed: ' + ', '.join(failed))
print(f'STUDY TUTORIAL TRIGGER CHECK PASSED: {len(checks)} checks')
