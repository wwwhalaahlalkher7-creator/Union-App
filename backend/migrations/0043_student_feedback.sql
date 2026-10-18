PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS student_feedback_reports (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('suggestion','bug','content','other')),
  title TEXT NOT NULL CHECK (length(title) BETWEEN 3 AND 120),
  details TEXT NOT NULL CHECK (length(details) BETWEEN 10 AND 3000),
  screen TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','resolved','dismissed')),
  admin_notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TEXT,
  reviewed_by TEXT REFERENCES staff_users(id)
);

CREATE INDEX IF NOT EXISTS idx_student_feedback_status_created
  ON student_feedback_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_feedback_student_created
  ON student_feedback_reports(student_id, created_at DESC);
