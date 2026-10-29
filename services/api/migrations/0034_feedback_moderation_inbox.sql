PRAGMA foreign_keys = ON;

-- Student-submitted suggestions and general reports.
CREATE TABLE IF NOT EXISTS feedback_reports (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('suggestion','report')),
  title TEXT,
  details TEXT NOT NULL,
  screen TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','resolved','dismissed','archived')),
  admin_notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_status_created ON feedback_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_student_created ON feedback_reports(student_id, created_at DESC);

-- Report snapshots are retained independently because this repository currently has no
-- public-chat message table to join against. message_status is a moderation decision
-- recorded on the report, not a mutation of a live chat message.
CREATE TABLE IF NOT EXISTS chat_reports (
  id TEXT PRIMARY KEY,
  reporter_student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  reported_message_id TEXT,
  author_name TEXT,
  message_body TEXT,
  reason TEXT NOT NULL,
  screen TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','dismissed','archived')),
  message_status TEXT NOT NULL DEFAULT 'visible' CHECK (message_status IN ('visible','hidden')),
  admin_notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_chat_reports_status_created ON chat_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_reports_student_created ON chat_reports(reporter_student_id, created_at DESC);
