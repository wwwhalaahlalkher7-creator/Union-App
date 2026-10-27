from pathlib import Path

root = Path(__file__).resolve().parents[1]
page = (root / 'apps/admin/lib/src/features/security/eino_monitor_page.dart').read_text(encoding='utf-8')
api_service = (root / 'apps/admin/lib/src/api_service.dart').read_text(encoding='utf-8')
worker = (root / 'services/api/src/index.js').read_text(encoding='utf-8')
admin = (root / 'services/api/src/admin.js').read_text(encoding='utf-8')
checks = {
    'native Eino monitor calls the supported endpoint': "'/admin/security/eino-usage?hours=$_hours'" in page and "path === '/admin/security/eino-usage'" in worker,
    'API response provides summary and time buckets': all(k in admin for k in ('summary:', 'buckets:', 'averageLatencyMs:', 'eventCount:')),
    'admin client exposes Eino usage API': "'/admin/security/eino-usage?hours=${hours.clamp(1, 168)}'" in api_service,
    'monitor renders request totals and latency data': all(k in page for k in ('eventCount', 'averageLatencyMs', 'totalLatencyMs', 'حدود الاستخدام')),
    'monitor privacy description avoids conversation content': 'دون عرض نصوص المحادثات أو معرفات الطلاب' in page,
}
for label, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ' ' + label)
if not all(checks.values()):
    raise SystemExit('EINO MONITOR CONTRACT CHECK FAILED')
print('EINO MONITOR CONTRACT CHECK PASSED')
