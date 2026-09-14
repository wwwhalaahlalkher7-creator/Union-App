from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=(root/'backend/src/index.js').read_text()
mg=(root/'backend/migrations/0017_eino_observability.sql').read_text()
checks={
 'telemetry table':'CREATE TABLE IF NOT EXISTS eino_telemetry' in mg,
 'hourly unique bucket':'UNIQUE(bucket_started_at, event_type, actor_type)' in mg,
 'privacy statement':'never prompts' in mg.lower(),
 'telemetry helper':'recordEinoTelemetry' in src,
 'success telemetry':"'success'" in src,
 'provider error telemetry':"'provider_error'" in src,
 'timeout telemetry':"'timeout'" in src,
 'quota telemetry':'quota_${rate.scope}' in src,
 'admin endpoint':"/admin/security/eino-usage" in src,
 'dashboard permission':"requireAdminPermission(ctx, 'dashboard.read')" in src,
 'no prompt column': 'prompt TEXT' not in mg and 'response TEXT' not in mg,
 'no ip column': 'ip TEXT' not in mg, 
 'no student id column':'student_id' not in mg.lower(),
}
for k,v in checks.items():
 print(('PASS' if v else 'FAIL'), k)
if not all(checks.values()): raise SystemExit(1)
print('EINO OBSERVABILITY CHECK PASSED')
