from pathlib import Path
root=Path(__file__).resolve().parents[1]
src='\n'.join(p.read_text() for p in (root/'services/api/src').rglob('*.js'))
mg=(root/'services/api/migrations/0017_eino_observability.sql').read_text()
detail_mg=(root/'services/api/migrations/0036_eino_provider_observability.sql').read_text()
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
 'provider detail telemetry migration':'CREATE TABLE IF NOT EXISTS eino_provider_telemetry' in detail_mg,
 'provider telemetry is hourly aggregated':'UNIQUE(bucket_started_at, capability, actor_type, provider, model, status)' in detail_mg,
 'provider telemetry has no prompt or response data':'prompt TEXT' not in detail_mg.lower() and 'response TEXT' not in detail_mg.lower(),
 'provider telemetry has no identity or IP fields':'student_id' not in detail_mg.lower() and 'ip TEXT' not in detail_mg.lower(),
 'provider and capability metrics are queried':'providerSummary' in src and 'detailBuckets' in src,
}
for k,v in checks.items():
 print(('PASS' if v else 'FAIL'), k)
if not all(checks.values()): raise SystemExit(1)
print('EINO OBSERVABILITY CHECK PASSED')
