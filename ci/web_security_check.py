from pathlib import Path

root = Path(__file__).resolve().parents[1]
public_worker = (root / 'web/portal/worker/index.js').read_text(encoding='utf-8')
admin_app = (root / 'apps/admin/lib/src/session_store.dart').read_text(encoding='utf-8')
api = '\n'.join(p.read_text(encoding='utf-8') for p in (root / 'services/api/src').rglob('*.js'))

checks = {
    'public CSP blocks plugin content and frames': "object-src 'none'" in public_worker and "frame-src 'none'" in public_worker,
    'public worker keeps admin routes unpublished': "path === '/admin' || path.startsWith('/admin/')" in public_worker and 'status: 404' in public_worker,
    'API security headers are defined': all(x in api for x in ["'x-content-type-options': 'nosniff'", "'x-frame-options': 'DENY'", "'referrer-policy': 'no-referrer'", "'cache-control': 'no-store'", "'content-security-policy': \"default-src 'none'"]),
    'native admin stores session using secure storage': 'FlutterSecureStorage' in admin_app,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('WEB SECURITY CHECK FAILED: ' + ', '.join(failed))
print('WEB SECURITY CHECK PASSED: public portal CSP, unpublished admin route, API security headers, secure native admin session')
