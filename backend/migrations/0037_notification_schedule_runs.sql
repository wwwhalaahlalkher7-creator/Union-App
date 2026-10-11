-- Record that a due announcement's recipient fan-out has been processed, including
-- announcements with zero registered recipients, to avoid re-scanning them every minute.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS notification_schedule_runs (
  announcement_id TEXT PRIMARY KEY REFERENCES announcements(id) ON DELETE CASCADE,
  processed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  target_count INTEGER NOT NULL DEFAULT 0
);
