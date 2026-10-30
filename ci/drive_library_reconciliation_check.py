#!/usr/bin/env python3
"""Static regression checks for the Drive ↔ D1 library reconciliation flow."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
drive = (ROOT / 'services/api/src/drive.js').read_text()
apps_script = (ROOT / 'services/api/App Script/TRINEX Drive.gs').read_text()
index = (ROOT / 'services/api/src/index.js').read_text()
admin = (ROOT / 'services/api/src/admin.js').read_text()
academic_ui = (ROOT / 'apps/admin/lib/src/features/academic/academic_page.dart').read_text(encoding='utf-8')
register = (ROOT / 'apps/student/lib/features/auth/register_screen.dart').read_text()
shell = (ROOT / 'apps/student/lib/shared/widgets/trinex_shell.dart').read_text()
tutorial = (ROOT / 'apps/student/lib/features/onboarding/guided_tour_overlay.dart').read_text()
profile = (ROOT / 'apps/student/lib/features/student/student_screen.dart').read_text()
offline_widget = (ROOT / 'apps/student/lib/shared/widgets/offline_banner.dart').read_text()

checks = {
    'stable Drive folder identity': 'drive-subject-${folderId}' in drive and 'materialFolderId' in apps_script,
    'empty material folders indexed': 'folders: folders' in apps_script and 'for (const folder of (Array.isArray(index.folders)' in drive,
    'renamed Drive files reconciled into D1': 'UPDATE materials SET title=?' in drive and "action === 'renameFile'" in apps_script,
    'renamed material folders reconciled into D1': 'UPDATE subjects SET name_ar=?,name_en=?' in drive and "action === 'renameFolder'" in apps_script,
    'Drive folder create route': "path === '/admin/drive/folders'" in index and "action === 'createFolder'" in apps_script,
    'Drive PDF upload route': "path === '/admin/drive/files'" in index and "action === 'uploadPdf'" in apps_script,
    'Drive file and folder deletion': "action === 'deleteFiles'" in apps_script and "action === 'deleteFolders'" in apps_script and 'deleteDriveFoldersViaAppsScript' in admin,
    'guard against incomplete sync deactivation': 'أُوقفت مزامنة الحذف لحماية البيانات الحالية' in drive,
    'native admin academic UI uses canonical API field names': all(key in academic_ui for key in ('department_id', 'semester_id', 'subject_id', 'day_of_week', 'start_time', 'end_time')),
    'tutorial triggered only after first-time registration': "result['registrationTransition'] == true" in register and 'setLearningModePendingFor(studentNumber, shouldStartTour)' in register and 'registrationTransition: true' in (ROOT / 'services/api/src/auth.js').read_text(),
    'tutorial is an in-app guided spotlight, not pre-login onboarding': 'GuidedTourOverlay' in shell and 'guidedTourSteps' in tutorial and 'CustomPaint' in tutorial,
    'personal study center stays on profile': 'personalStudyCenter' in profile and "context.go('/progress')" in profile,
    'exam API safely isolates the dedicated exam library': "action === 'exams'" in apps_script and 'export async function adminExams' in drive and "path === '/admin/exams'" in index,
    'offline banner replaced with compact Wi-Fi states': 'Icons.wifi_off_rounded' in offline_widget and 'Icons.wifi_rounded' in offline_widget and 'StackFit.expand' in offline_widget,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed:
    raise SystemExit('Drive library reconciliation check failed: ' + ', '.join(failed))
print(f'DRIVE LIBRARY RECONCILIATION CHECK PASSED: {len(checks)} checks')
