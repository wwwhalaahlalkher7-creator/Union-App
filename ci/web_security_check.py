from pathlib import Path

root = Path(__file__).resolve().parents[1]
public_worker = (root / 'website/worker/index.js').read_text(encoding='utf-8')
api = '\\n'.join(p.read_text(encoding='utf-8') for p in (root / 'backend/src').rglob('*.js'))
checks = {
    'public CSP object/frame hardening': "object-src 'none'" in public_worker and "frame-src 'none'" in public_worker,
    'web admin route is disabled': "path === '/admin' || path.startsWith('/admin/')" in public_worker and 'status: 404' in public_worker,
    'API security headers': all(marker in api for marker in [
        "'x-content-type-options': 'nosniff'",
        "'x-frame-options': 'DENY'",
        "'referrer-policy': 'no-referrer'",
        "'cache-control': 'no-store'",
        "'content-security-policy': \"default-src 'none';",
    ]),
    'no web admin source directory': not (root / 'website/admin').exists(),
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('WEB SECURITY CHECK FAILED: ' + ', '.join(failed))
print('WEB SECURITY CHECK PASSED: public-site hardening, disabled web-admin route, and API security headers')
