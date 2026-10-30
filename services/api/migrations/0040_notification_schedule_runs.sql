-- Idempotency marker for scheduled announcement fan-out. Records are retained
-- even when an announcement targets zero registered students so the scheduler
-- does not repeatedly scan the same already-due announcement.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS notification_schedule_runs (
  announcement_id TEXT PRIMARY KEY REFERENCES announcements(id) ON DELETE CASCADE,
  processed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  target_count INTEGER NOT NULL DEFAULT 0
);
