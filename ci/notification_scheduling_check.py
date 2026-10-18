#!/usr/bin/env python3
"""Regression checks for end-to-end announcement publishing and scheduling."""
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
admin = (ROOT / 'backend/src/admin.js').read_text(encoding='utf-8')
drafts = (ROOT / 'backend/src/notification_drafts.js').read_text(encoding='utf-8')
notifications = (ROOT / 'backend/src/notifications.js').read_text(encoding='utf-8')
scheduler = (ROOT / 'backend/src/scheduler.js').read_text(encoding='utf-8')
student = (ROOT / 'backend/src/student.js').read_text(encoding='utf-8')
migration = (ROOT / 'backend/migrations/0045_notification_auto_publish.sql').read_text(encoding='utf-8')

checks = {
    'manual notifications always published': "if (table === 'announcements')" in admin and "fields.status = 'published'" in admin,
    'automatic type from audience': "fields.type = fields.target_department_id || fields.target_semester_id ? 'academic' : 'general'" in admin,
    'category follows automatic type': 'fields.notification_category = fields.type' in admin,
    'timezone normalization is explicit': 'normalizeAnnouncementTimestamp' in admin and '+02:00' in admin and 'toISOString()' in admin,
    'expiration must follow publish time': "Date.parse(expiresAt) <= Date.parse(publishAt)" in admin,
    'legacy scheduled state maps to published': "fields.status === 'scheduled') fields.status = 'published'" in admin,
    'schedule/material are the only content drafts': "!['schedules', 'materials'].includes(table)" in drafts and "'achievements'" not in drafts,
    'scheduled notices are not materialized before publish': 'datetime(a.publish_at) <= datetime(?)' in notifications,
    'expired notices are excluded from delivery': 'datetime(a.expires_at) > datetime(?)' in notifications,
    'scheduler includes published notices by publish_at': "FROM announcements a\n         WHERE a.status='published'" in scheduler and 'COALESCE(a.publish_at, a.created_at)' in scheduler,
    'academic drafts require explicit approval': "UPDATE announcements SET status='published'" not in scheduler and "FROM announcements\n         WHERE status='draft' AND publish_at IS NOT NULL" not in scheduler,
    'student API hides future and expired notices': "datetime(a.publish_at) <= CURRENT_TIMESTAMP" in student and "datetime(a.expires_at) > CURRENT_TIMESTAMP" in student,
    'legacy non-academic drafts auto-promote': "content_type NOT IN ('schedule', 'material')" in migration,
    'legacy local notification times normalize to UTC': "'-2 hours'" in migration and "strftime('%Y-%m-%dT%H:%M:%fZ'" in migration,
}
failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'} {name}")
if failed:
    raise SystemExit('Notification scheduling checks failed: ' + ', '.join(failed))

# Exercise migration 0045 against representative legacy values, not only an
# empty schema: manual/achievement drafts promote, academic drafts remain drafts,
# naive Sudan wall times move to UTC, and explicitly-zoned timestamps stay exact.
db = sqlite3.connect(':memory:')
db.execute('CREATE TABLE announcements (id TEXT PRIMARY KEY, status TEXT, content_type TEXT, publish_at TEXT, expires_at TEXT, updated_at TEXT)')
db.executemany(
    'INSERT INTO announcements(id,status,content_type,publish_at,expires_at,updated_at) VALUES(?,?,?,?,?,?)',
    [
        ('manual', 'draft', None, '2026-10-20T12:00:00', '2026-10-22T14:00:00', 'old'),
        ('achievement', 'draft', 'achievement', None, None, 'old'),
        ('schedule', 'draft', 'schedule', None, None, 'old'),
        ('material', 'draft', 'material', None, None, 'old'),
        ('zoned', 'published', None, '2026-10-20T10:00:00.000Z', None, 'old'),
    ],
)
db.executescript(migration)
rows = {row[0]: row[1:] for row in db.execute('SELECT id,status,publish_at,expires_at FROM announcements')}
assert rows['manual'][0] == 'published', 'manual draft was not promoted'
assert rows['achievement'][0] == 'published', 'achievement draft was not promoted'
assert rows['schedule'][0] == 'draft' and rows['material'][0] == 'draft', 'academic draft was not preserved'
assert rows['manual'][1] == '2026-10-20T10:00:00.000Z', f"naive publish time not normalized: {rows['manual'][1]}"
assert rows['manual'][2] == '2026-10-22T12:00:00.000Z', f"naive expiry time not normalized: {rows['manual'][2]}"
assert rows['zoned'][1] == '2026-10-20T10:00:00.000Z', f"zoned publish time shifted unexpectedly: {rows['zoned'][1]}"
db.close()
print('PASS migration data smoke test: statuses and timestamp normalization')
print(f'NOTIFICATION SCHEDULING CHECK PASSED ({len(checks)} checks)')
