#!/usr/bin/env python3
"""Static XSS hygiene checks for the public portal included in this monorepo."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PORTAL = ROOT / 'web/portal'
html_files = list(PORTAL.glob('*.html'))
js_files = list(PORTAL.glob('*.js'))
html = '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in html_files)
js = '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in js_files)
worker = (PORTAL / 'worker/index.js').read_text(encoding='utf-8')
checks = {
    'public portal HTML files exist': len(html_files) >= 5,
    'no javascript: URLs in public HTML': not re.search(r'(?i)href\s*=\s*["\']\s*javascript:', html),
    'no inline event handlers in public HTML': not re.search(r'(?i)\son(?:click|change|input|submit|error|load)\s*=', html),
    'public JavaScript avoids eval and document.write': not re.search(r'\beval\s*\(', js) and not re.search(r'\bdocument\.write\s*\(', js),
    'Worker explicitly keeps administrative routes unpublished': "path === '/admin' || path.startsWith('/admin/')" in worker and 'status: 404' in worker,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed: raise SystemExit('PUBLIC PORTAL XSS CHECK FAILED: ' + ', '.join(failed))
print(f'PUBLIC PORTAL XSS CHECK PASSED: {len(checks)} checks')
