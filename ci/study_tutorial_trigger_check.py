#!/usr/bin/env python3
"""Guard the account-scoped post-registration guided tour."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
register = (ROOT / 'apps/student/lib/features/auth/register_screen.dart').read_text()
login = (ROOT / 'apps/student/lib/features/auth/login_screen.dart').read_text()
onboarding = (ROOT / 'apps/student/lib/features/onboarding/onboarding_screen.dart').read_text()
shell = (ROOT / 'apps/student/lib/shared/widgets/trinex_shell.dart').read_text()
overlay = (ROOT / 'apps/student/lib/features/onboarding/guided_tour_overlay.dart').read_text()
preferences = (ROOT / 'apps/student/lib/core/storage/app_preferences.dart').read_text()
auth = (ROOT / 'services/api/src/auth.js').read_text()
test = (ROOT / 'apps/student/test/study_tutorial_trigger_test.dart').read_text()

checks = {
    'registration response explicitly identifies the first registration transition': "registrationTransition: true" in auth and "identity.registrationTransition === true" in auth and "registrationTransition: true" in auth,
    'registration schedules the tour only after a confirmed transition': "result['registrationTransition'] == true" in register and "result['registered'] == true" in register and 'setLearningModePendingFor(studentNumber, shouldStartTour)' in register,
    'tour state is account-scoped and completion is persisted per student': '_tutorialPendingPrefix' in preferences and 'learningModePendingFor(String studentNumber)' in preferences and 'setLearningModeCompletedFor' in preferences,
    'ordinary login does not create a registration tour': 'setLearningModePendingFor' not in login,
    'guest onboarding does not create a registration tour': 'setLearningModePendingFor' not in onboarding,
    'shell reads the pending flag for the authenticated student': 'authStorage.studentNumber' in shell and 'learningModePendingFor(studentNumber)' in shell and 'learningModeCompletedFor(studentNumber)' in shell,
    'tour waits for the actual home shell target': "widget.location != '/home'" in shell and 'guidedTourHomeNavKey.currentContext' in shell,
    'tour is a spotlight overlay with real navigation and Eino anchors': 'class GuidedTourOverlay' in overlay and 'CustomPaint' in overlay and 'guidedTourHomeNavKey' in overlay and 'guidedTourMaterialsKey' in overlay and 'guidedTourEinoKey' in overlay,
    'shell advances and completes the guided route sequence': 'GuidedTourOverlay(' in shell and '_onGuidedTourTargetTap' in shell and '_completeGuidedTour' in shell,
    'widget tests cover account-scoped state and real spotlight interaction': 'learningModePendingFor' in test and 'GuidedTourOverlay' in test and 'guidedTourHomeNavKey' in test,
}
for name, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ' ' + name)
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit('Guided tour checks failed: ' + ', '.join(failed))
print(f'GUIDED TOUR CHECK PASSED: {len(checks)} checks')
