#!/usr/bin/env python3
"""Static checks for API/schema integrity invariants that are easy to regress."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / 'backend/src/index.js').read_text(encoding='utf-8')

required = {
    'content target validation': r'async function contentIsCommentable\(',
    'comment target validation': r'contentIsCommentable\(ctx, parts\[2\], parts\[3\]\)',
    'schedule subject consistency': r'SCHEDULE_SUBJECT_MISMATCH',
    'database unique conflict mapping': r'UNIQUE constraint failed',
    'notification push idempotency': r'INSERT OR IGNORE INTO notification_dispatch_queue',
    'historical material semester lookup': r'SELECT id FROM semesters WHERE id = \?',
}
for name, pattern in required.items():
    if not re.search(pattern, src):
        raise SystemExit(f'Missing API integrity invariant: {name}')

# The authenticated material query must not require an active semester.
material_block = src[src.find('async function materials(ctx)'):src.find('\nasync function materialById', src.find('async function materials(ctx)'))]
if re.search(r'JOIN semesters\s+sem', material_block, re.I) or re.search(r'semesters\s+WHERE[^;]+active\s*=\s*1', material_block, re.I):
    raise SystemExit('Authenticated material API accidentally became current-semester-only')

# Google Drive deletion must happen before D1 material deletion.
drive_pos = src.find('await deleteDriveFilesViaAppsScript(ctx, [fileId])')
d1_pos = src.find("DELETE FROM materials WHERE id=?", drive_pos)
if drive_pos < 0 or d1_pos < 0 or drive_pos > d1_pos:
    raise SystemExit('Drive deletion ordering invariant is broken')

print('backend API integrity audit: PASS')
