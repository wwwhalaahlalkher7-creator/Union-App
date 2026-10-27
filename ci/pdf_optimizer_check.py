#!/usr/bin/env python3
"""PDF upload safety checks for the current native-admin/API layout."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'services/api/src/drive.js').read_text(encoding='utf-8')
apps_script = (ROOT / 'services/api/App Script/TRINEX Drive.gs').read_text(encoding='utf-8')
checks = {
    'Worker upload body has a 20 MiB base64-size guard': 'base64.length > 28_000_000' in worker,
    'Apps Script checks the PDF header before saving': 'bytes[0] !== 37' in apps_script and 'bytes[4] !== 45' in apps_script,
    'Apps Script enforces decoded file size': 'bytes.length > 20 * 1024 * 1024' in apps_script,
    'Worker stores uploaded material PDFs with the PDF MIME type': "'application/pdf'" in worker,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed: raise SystemExit('PDF upload safety check failed: ' + ', '.join(failed))
print(f'PDF UPLOAD SAFETY CHECK PASSED: {len(checks)} checks')
