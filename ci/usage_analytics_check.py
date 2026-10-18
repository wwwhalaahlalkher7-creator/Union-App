#!/usr/bin/env python3
"""Static and SQLite smoke checks for anonymous usage analytics."""
from pathlib import Path
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

migration = ROOT / 'backend/migrations/0039_usage_analytics.sql'
source = (ROOT / 'backend/src/analytics.js').read_text(encoding='utf-8')
index = (ROOT / 'backend/src/index.js').read_text(encoding='utf-8')
site_script = (ROOT / 'website/analytics.js').read_text(encoding='utf-8')
app_tracker = (ROOT / 'flutter/lib/core/analytics/usage_analytics.dart').read_text(encoding='utf-8')

check('migration exists', migration.exists())
if migration.exists():
    db = sqlite3.connect(':memory:')
    db.executescript(migration.read_text(encoding='utf-8'))
    db.execute("INSERT INTO usage_sessions(session_hash, platform) VALUES ('hash-test','app')")
    db.execute("INSERT INTO usage_events(id, session_hash, platform, event_name, section) VALUES ('event-test','hash-test','app','screen_view','home')")
    check('migration schema and insert smoke test', db.execute('SELECT COUNT(*) FROM usage_events').fetchone()[0] == 1)
    columns = {r[1] for r in db.execute('PRAGMA table_info(usage_events)')}
    check('no account/IP/user-agent/content columns', not columns.intersection({'student_id','staff_user_id','ip_address','user_agent','body','content','search_term'}))
check('public event route', "path === '/usage/events' && request.method === 'POST'" in index)
check('admin aggregate route', "path === '/admin/analytics/overview' && request.method === 'GET'" in index)
check('admin permission enforced', "requireAdminPermission(ctx, 'superadmin.read')" in source)
check('session token hashed before persistence', 'await sha256(`trinex-usage-v1:${sessionId}`)' in source)
check('rate limit exists', '>= 60' in source and "datetime('now','-1 minute')" in source)
check('website omits credentials', "credentials: 'omit'" in site_script)
check('website does not send query strings', 'location.search' not in site_script and 'location.href' not in site_script)
check('app never sends route path', "'section': section" in app_tracker and "'path':" not in app_tracker)
for page in (ROOT / 'website').rglob('*.html'):
    content = page.read_text(encoding='utf-8', errors='ignore')
    if '</body>' in content.lower():
        check(f'{page.relative_to(ROOT)} includes analytics.js', 'analytics.js' in content)

# Phase 2 resource telemetry and student moderation guardrails.
resource_migration = ROOT / 'backend/migrations/0040_student_moderators_and_resource_usage.sql'
resource_source = (ROOT / 'backend/src/index.js').read_text(encoding='utf-8')
chat_source = (ROOT / 'backend/src/chat.js').read_text(encoding='utf-8')
interaction_source = (ROOT / 'backend/src/interactions.js').read_text(encoding='utf-8')
admin_source = (ROOT / 'backend/src/admin.js').read_text(encoding='utf-8')
admin_config = (ROOT / 'backend/src/admin/config.js').read_text(encoding='utf-8')
chat_ui = (ROOT / 'flutter/lib/features/chat/general_chat_screen.dart').read_text(encoding='utf-8')
comments_ui = (ROOT / 'flutter/lib/features/news/content_comments_sheet.dart').read_text(encoding='utf-8')
check('resource usage migration', resource_migration.exists() and 'resource_usage_events' in resource_migration.read_text(encoding='utf-8'))
if resource_migration.exists():
    resource_db = sqlite3.connect(':memory:')
    resource_db.executescript('CREATE TABLE students (id TEXT PRIMARY KEY, active INTEGER NOT NULL DEFAULT 1, updated_at TEXT DEFAULT CURRENT_TIMESTAMP);')
    resource_db.executescript(resource_migration.read_text(encoding='utf-8'))
    student_columns = {row[1] for row in resource_db.execute('PRAGMA table_info(students)')}
    resource_columns = {row[1] for row in resource_db.execute('PRAGMA table_info(resource_usage_events)')}
    check('student moderator migration smoke test', 'is_moderator' in student_columns)
    check('resource usage schema smoke test', {'route','d1_operations','r2_operations','r2_read_bytes'} <= resource_columns)
    resource_db.execute("INSERT INTO resource_usage_events(id,route,method,status_code,d1_operations,r2_operations,r2_read_bytes) VALUES('smoke','/media/:key','GET',200,2,1,512)")
    check('resource usage insert smoke test', resource_db.execute("SELECT SUM(d1_operations) FROM resource_usage_events").fetchone()[0] == 2)
check('D1 request instrumentation', 'instrumentD1' in resource_source and 'd1Operations' in resource_source)
check('resource usage top-three aggregate', 'topConsumers' in source and 'topR2' in source and 'topD1' in source)
check('student supervisor admin route', 'adminSetStudentModerator' in admin_source and "is_moderator" in admin_config)
check('moderator-gated public chat delete', 'student_is_moderator' in chat_source and 'moderated: isModerator' in chat_source)
check('moderator-gated comment/reply delete', 'student_is_moderator' in interaction_source and 'moderated: isModerator' in interaction_source)
check('chat delete option gated in UI', 'mine || _isModerator' in chat_ui)
check('comment/reply delete option gated in UI', '|| _isModerator' in comments_ui)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed:
    print(f'USAGE ANALYTICS CHECK FAILED ({len(failed)} failures)')
    sys.exit(1)
print(f'USAGE ANALYTICS CHECK PASSED ({len(checks)} checks)')

