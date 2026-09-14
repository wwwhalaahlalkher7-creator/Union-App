from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DASH = ROOT / 'website' / 'dashboard'

html = '\n'.join(p.read_text(errors='ignore') for p in DASH.glob('*.html'))
js = '\n'.join(p.read_text(errors='ignore') for p in (DASH/'js').glob('*.js'))

checks = {
    'no dynamic row onclick handlers': not re.search(r"onclick=['\"](?:openForm|toggleStudent|deleteStudent|toggleEntry|deleteEntry|moderate)\\?\(", html),
    'modal confirm uses textContent': 'p.textContent = message == null ? "" : String(message);' in (DASH/'js'/'modal.js').read_text(),
    'modal body is rebuilt from template only': 'body.replaceChildren();' in (DASH/'js'/'modal.js').read_text(),
    'no javascript URLs in dashboard HTML': not re.search(r'(?i)href\\s*=\\s*["\']\\s*javascript:', html),
    'no inline event attributes for protected dynamic actions': not re.search(r'(?i)on(?:click|change|input|submit)\\s*=.*(?:openForm|toggleStudent|deleteStudent|toggleEntry|deleteEntry|moderate)', html),
}
failed = [k for k,v in checks.items() if not v]
if failed:
    raise SystemExit('XSS DOM CHECK FAILED: ' + ', '.join(failed))
print('XSS DOM CHECK PASSED: modal text isolation and dynamic-action handler hardening')
