PRAGMA foreign_keys = ON;

ALTER TABLE material_progress ADD COLUMN active_seconds INTEGER NOT NULL DEFAULT 0;
ALTER TABLE material_progress ADD COLUMN last_progress_at TEXT;

CREATE TABLE IF NOT EXISTS material_progress_events (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id),
  material_id TEXT NOT NULL REFERENCES materials(id),
  event_type TEXT NOT NULL,
  progress_percent INTEGER,
  active_seconds INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_progress_events_student_created
  ON material_progress_events(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_progress_events_material_created
  ON material_progress_events(material_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_progress_student_last
  ON material_progress(student_id, last_progress_at DESC);
