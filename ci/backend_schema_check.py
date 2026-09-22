#!/usr/bin/env python3
"""Validate the complete D1 migration chain and backend hardening invariants."""
from pathlib import Path
import re
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
MIGRATIONS = sorted(BACKEND.glob("migrations/*.sql"))
INDEX_JS = (BACKEND / "src/index.js").read_text(encoding="utf-8")

if not MIGRATIONS:
    raise SystemExit("No backend migrations found")

conn = sqlite3.connect(":memory:")
conn.execute("PRAGMA foreign_keys=ON")
for migration in MIGRATIONS:
    conn.executescript(migration.read_text(encoding="utf-8"))

fk_errors = list(conn.execute("PRAGMA foreign_key_check"))
if fk_errors:
    raise SystemExit(f"Foreign-key check failed: {fk_errors[:5]}")

required_tables = {
    "students", "departments", "semesters", "subjects", "materials", "schedules",
    "sessions", "staff_users", "notification_targets", "notification_devices",
    "notification_dispatch_queue", "comments", "comment_replies", "reactions",
    "comment_reactions", "material_progress", "material_progress_events",
    "xp_events", "student_stats", "badges", "student_badges", "eino_memories",
}
tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
missing = sorted(required_tables - tables)
if missing:
    raise SystemExit(f"Missing required tables: {missing}")

required_indexes = {
    "idx_material_progress_material_student",
    "idx_comment_replies_student",
    "idx_comment_reactions_student",
    "idx_notification_queue_target",
    "idx_notification_targets_announcement_student",
    "idx_students_department_semester_active",
    "idx_subjects_department_semester_active",
    "idx_schedules_department_semester_active_time",
    "idx_notification_targets_student_read",
}
indexes = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='index'")}
missing_indexes = sorted(required_indexes - indexes)
if missing_indexes:
    raise SystemExit(f"Missing hardening indexes: {missing_indexes}")

# Verify the intentional material policy: students may explicitly browse
# historical semesters, including archived/inactive terms, while remaining
# constrained to their own department.
if "async function effectiveMaterialSemester" not in INDEX_JS:
    raise SystemExit("Historical material semester resolver is missing")
materials_start = INDEX_JS.index("async function materials")
materials_end = INDEX_JS.index("async function materialById", materials_start)
materials_code = INDEX_JS[materials_start:materials_end]
if "effectiveMaterialSemester(ctx, a.session, requestedSemester)" not in materials_code or "s.department_id = ?" not in materials_code:
    raise SystemExit("Material endpoint no longer preserves historical-semester access policy")

# Verify the intentional Drive coupling: D1 deletion must stop when external
# Drive deletion fails.
if "DRIVE_DELETE_FAILED" not in INDEX_JS or "لم يتم حذف سجل D1" not in INDEX_JS:
    raise SystemExit("Drive deletion coupling guard is missing")

# Regression checks for the specific backend fixes.
checks = {
    "event comment type": "table === 'news' ? 'news' : table === 'events' ? 'event' : 'activity'",
    "student reply cleanup": "DELETE FROM comment_replies WHERE student_id=?",
    "student Eino memory cleanup": "DELETE FROM eino_memories WHERE student_id=?",
    "atomic XP condition": "INSERT INTO xp_events (id, student_id, event_type, source_id, xp)\n    SELECT ?, ?, ?, ?, ?",
    "set based notifications": "INSERT INTO notification_targets (id, announcement_id, student_id)\n    SELECT lower(hex(randomblob(16))), ?, s.id",
    "batched badges": "ctx.env.DB.batch(\n    eligible.map",
    "external timeout helper": "async function fetchWithTimeout",
    "atomic student auth lock": "failed_login_attempts = failed_login_attempts + 1",
    "atomic staff auth lock": "UPDATE staff_users\n      SET failed_login_attempts = failed_login_attempts + 1",
    "set based notification read": "UPDATE notification_targets\n     SET read_at = COALESCE(read_at, ?)",
}
for name, needle in checks.items():
    if needle not in INDEX_JS:
        raise SystemExit(f"Regression check failed: {name}")

print(f"Backend schema validation passed: {len(MIGRATIONS)} migrations, {len(tables)} tables, {len(indexes)} indexes")
