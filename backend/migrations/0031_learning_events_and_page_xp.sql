PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS learning_events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  design TEXT NOT NULL DEFAULT 'standard',
  config_json TEXT,
  xp_reward INTEGER NOT NULL DEFAULT 25,
  target_department_id TEXT REFERENCES departments(id),
  target_semester_id TEXT REFERENCES semesters(id),
  publish_at TEXT,
  expires_at TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  created_by TEXT REFERENCES staff_users(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS learning_event_completions (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES learning_events(id),
  student_id TEXT NOT NULL REFERENCES students(id),
  completed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(event_id, student_id)
);

ALTER TABLE announcements ADD COLUMN learning_event_id TEXT REFERENCES learning_events(id);
ALTER TABLE material_progress ADD COLUMN last_page_number INTEGER NOT NULL DEFAULT 0;
ALTER TABLE material_progress ADD COLUMN page_count INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_learning_events_status_publish
  ON learning_events(status, publish_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_learning_event_completions_student
  ON learning_event_completions(student_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_learning_event
  ON announcements(learning_event_id);
