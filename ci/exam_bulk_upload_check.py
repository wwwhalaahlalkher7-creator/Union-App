#!/usr/bin/env python3
"""Regression checks for the Worker/Apps Script dedicated exam PDF API."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'services/api/src/drive.js').read_text(encoding='utf-8')
apps_script = (ROOT / 'services/api/App Script/TRINEX Drive.gs').read_text(encoding='utf-8')
index = (ROOT / 'services/api/src/index.js').read_text(encoding='utf-8')
checks = {
    'exam listing/upload endpoint is registered': "path === '/admin/exams'" in index and 'adminExams(ctx)' in index,
    'exam uploads are stored in a dedicated exams folder': "name: 'exams'" in worker and "action === 'exams'" in apps_script,
    'API validates base64 PDF upload size': 'base64.length > 28_000_000' in worker and 'EXAM_UPLOAD_INVALID' in worker,
    'Apps Script checks actual PDF signature': 'bytes[0] !== 37' in apps_script and 'bytes[4] !== 45' in apps_script,
    'Apps Script enforces 20 MiB maximum': 'bytes.length > 20 * 1024 * 1024' in apps_script,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed: raise SystemExit('Exam PDF API guard check failed: ' + ', '.join(failed))
print(f'EXAM PDF API GUARD CHECK PASSED: {len(checks)} checks')
