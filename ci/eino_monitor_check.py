from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
admin=(ROOT/'backend/src/admin.js').read_text()
index=(ROOT/'backend/src/index.js').read_text()
mig=(ROOT/'backend/migrations/0034_eino_request_observability.sql').read_text()
page=(ROOT/'website/admin/eino-monitor.html').read_text()
layout=(ROOT/'website/admin/js/layout.js').read_text()
adapter=(ROOT/'website/admin/js/api-adapter.js').read_text()
flutter=(ROOT/'flutter/lib/features/eino/eino_screen.dart').read_text()
checks=[
('request telemetry table','CREATE TABLE IF NOT EXISTS eino_request_telemetry' in mig),
('no prompt storage', 'prompt' not in mig.split('CREATE TABLE')[1].split(');')[0].lower() and 'response' not in mig.split('CREATE TABLE')[1].split(');')[0].lower()),
('no student id storage', 'student_id' not in mig.lower()),
('no ip storage', 'ip_address' not in mig.lower()),
('admin-only backend permission', "requireAdminPermission(ctx, 'superadmin.read')" in admin),
('monitor route', "'/admin/security/eino-monitor'" in index),
('monitor page', 'مراقبة Eino' in page),
('monitor adapter', 'getEinoMonitor' in adapter),
('admin-only navigation', 'einoMonitor' in layout and 'super_admin' in layout),
('first-open notice', 'eino_data_notice_seen_v1' in flutter),
('notice explains analytics', 'تحليل أداء Eino' in flutter),
]
failed=[name for name,ok in checks if not ok]
if failed: raise SystemExit('EINO MONITOR CHECK FAILED: '+', '.join(failed))
print('EINO MONITOR CHECK PASSED')
