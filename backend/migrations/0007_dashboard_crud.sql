-- Stage 9 — Dashboard CRUD + audit attribution
PRAGMA foreign_keys = ON;
ALTER TABLE achievements ADD COLUMN created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE achievements ADD COLUMN updated_by TEXT REFERENCES staff_users(id);
ALTER TABLE schedules ADD COLUMN created_by TEXT REFERENCES staff_users(id);
ALTER TABLE schedules ADD COLUMN updated_by TEXT REFERENCES staff_users(id);
ALTER TABLE subjects ADD COLUMN created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE subjects ADD COLUMN updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE badges ADD COLUMN created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE badges ADD COLUMN updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_news_status_publish ON news(status, publish_at);
CREATE INDEX IF NOT EXISTS idx_activities_status_event ON activities(status, event_at);
CREATE INDEX IF NOT EXISTS idx_achievements_status_date ON achievements(status, achieved_at);
CREATE INDEX IF NOT EXISTS idx_announcements_status_publish ON announcements(status, publish_at);
CREATE INDEX IF NOT EXISTS idx_students_active_name ON students(active, full_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
