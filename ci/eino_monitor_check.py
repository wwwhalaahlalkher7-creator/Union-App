from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
admin = (ROOT / 'backend/src/admin.js').read_text()
index = (ROOT / 'backend/src/index.js').read_text()
mig = (ROOT / 'backend/migrations/0034_eino_request_observability.sql').read_text()
flutter = (ROOT / 'flutter/lib/features/eino/eino_screen.dart').read_text()
checks = [
 ('request telemetry table', 'CREATE TABLE IF NOT EXISTS eino_request_telemetry' in mig),
 ('no prompt storage', 'prompt' not in mig.split('CREATE TABLE')[1].split(');')[0].lower() and 'response' not in mig.split('CREATE TABLE')[1].split(');')[0].lower()),
 ('no student id storage', 'student_id' not in mig.lower()),
 ('no ip storage', 'ip_address' not in mig.lower()),
 ('admin-only backend permission', "requireAdminPermission(ctx, 'superadmin.read')" in admin),
 ('monitor route', "'/admin/security/eino-monitor'" in index),
 ('first-open notice', 'eino_data_notice_seen_v1' in flutter),
 ('notice explains analytics', 'تحليل أداء Eino' in flutter),
 ('legacy web admin absent', not (ROOT / 'website/admin').exists()),
]
failed=[name for name,ok in checks if not ok]
if failed: raise SystemExit('EINO MONITOR CHECK FAILED: '+', '.join(name for name,_ in failed))
print('EINO MONITOR API CHECK PASSED')
