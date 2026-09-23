from pathlib import Path

root = Path(__file__).resolve().parents[1]
public_worker = (root / 'website/worker/index.js').read_text(encoding='utf-8')
dash_worker = (root / 'website/admin/worker/index.js').read_text(encoding='utf-8')
auth = (root / 'website/admin/js/auth.js').read_text(encoding='utf-8')
redirect = (root / 'website/admin/js/auth-check-redirect.js').read_text(encoding='utf-8')
login = (root / 'website/admin/login.html').read_text(encoding='utf-8')
api = (root / 'backend/src/index.js').read_text(encoding='utf-8')

checks = {
    'dashboard session-only auth storage': 'sessionStorage.setItem(KEY' in auth and 'sessionStorage.getItem(KEY' in auth and 'sessionStorage.removeItem(KEY' in auth,
    'login uses Auth.save': 'window.Auth.save(session)' in login,
    'login redirect uses sessionStorage': 'sessionStorage.getItem("assoc_admin_session")' in redirect,
    'public CSP object/frame hardening': "object-src 'none'" in public_worker and "frame-src 'none'" in public_worker,
    'dashboard CSP object/frame hardening': "object-src 'none'" in dash_worker and "frame-src 'none'" in dash_worker,
    'API security headers': all(x in api for x in ["'x-content-type-options': 'nosniff'", "'x-frame-options': 'DENY'", "'referrer-policy': 'no-referrer'", "'cache-control': 'no-store'", "'content-security-policy': \"default-src 'none'"]),
    'no dashboard auth localStorage': 'localStorage' not in auth and 'localStorage' not in redirect,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('WEB SECURITY CHECK FAILED: ' + ', '.join(failed))
print('WEB SECURITY CHECK PASSED: session-only dashboard auth, hardened static CSP, and API security headers')
