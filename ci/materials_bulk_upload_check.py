#!/usr/bin/env python3
"""Regression checks for the Worker/Apps Script PDF materials upload boundary."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'services/api/src/drive.js').read_text(encoding='utf-8')
apps_script = (ROOT / 'services/api/App Script/TRINEX Drive.gs').read_text(encoding='utf-8')
index = (ROOT / 'services/api/src/index.js').read_text(encoding='utf-8')
checks = {
    'materials PDF upload is routed through the API': "path === '/admin/drive/files'" in index and 'adminDriveUploadPdf' in index,
    'backend rejects oversized base64 PDF payloads': 'base64.length > 28_000_000' in worker and 'DRIVE_UPLOAD_TOO_LARGE' in worker,
    'backend upload calls the Drive Apps Script adapter': "'uploadPdf'" in worker and 'callAppsScriptDriveAction' in worker,
    'Apps Script validates PDF signature': 'bytes[0] !== 37' in apps_script and 'bytes[4] !== 45' in apps_script,
    'Apps Script limits decoded PDFs to 20 MiB': 'bytes.length > 20 * 1024 * 1024' in apps_script,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed: raise SystemExit('Materials PDF upload guard check failed: ' + ', '.join(failed))
print(f'MATERIALS PDF UPLOAD GUARD CHECK PASSED: {len(checks)} checks')
