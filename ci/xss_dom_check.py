from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
website = ROOT / 'website'
if (website / 'admin').exists():
    raise SystemExit('XSS DOM CHECK FAILED: legacy web admin directory must not exist')
html_files = list(website.glob('*.html'))
bad = []
for path in html_files:
    source = path.read_text(errors='ignore')
    if re.search(r'''(?i)href\\s*=\\s*["']\\s*javascript:''', source):
        bad.append(f'javascript URL in {path.relative_to(ROOT)}')
if bad:
    raise SystemExit('XSS DOM CHECK FAILED: ' + ', '.join(bad))
print(f'XSS DOM CHECK PASSED: legacy web admin removed; scanned {len(html_files)} public pages')
