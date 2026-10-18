-- Add a durable archived state to both moderation queues without conflating it with rejection.
PRAGMA foreign_keys = ON;

CREATE TABLE student_feedback_reports_new (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('suggestion','bug','content','other')),
  title TEXT NOT NULL CHECK (length(title) BETWEEN 3 AND 120),
  details TEXT NOT NULL CHECK (length(details) BETWEEN 10 AND 3000),
  screen TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','resolved','dismissed','archived')),
  admin_notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TEXT,
  reviewed_by TEXT REFERENCES staff_users(id)
);
INSERT INTO student_feedback_reports_new
  (id, student_id, category, title, details, screen, status, admin_notes, created_at, updated_at, reviewed_at, reviewed_by)
SELECT id, student_id, category, title, details, screen, status, admin_notes, created_at, updated_at, reviewed_at, reviewed_by
FROM student_feedback_reports;
DROP TABLE student_feedback_reports;
ALTER TABLE student_feedback_reports_new RENAME TO student_feedback_reports;
CREATE INDEX IF NOT EXISTS idx_student_feedback_status_created ON student_feedback_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_feedback_student_created ON student_feedback_reports(student_id, created_at DESC);

CREATE TABLE public_chat_reports_new (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL REFERENCES public_chat_messages(id) ON DELETE CASCADE,
  reporter_student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('spam','harassment','inappropriate','other')),
  details TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','dismissed','archived')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TEXT,
  reviewed_by TEXT,
  UNIQUE(message_id, reporter_student_id)
);
INSERT INTO public_chat_reports_new
  (id, message_id, reporter_student_id, reason, details, status, created_at, reviewed_at, reviewed_by)
SELECT id, message_id, reporter_student_id, reason, details, status, created_at, reviewed_at, reviewed_by
FROM public_chat_reports;
DROP TABLE public_chat_reports;
ALTER TABLE public_chat_reports_new RENAME TO public_chat_reports;
CREATE INDEX IF NOT EXISTS idx_public_chat_reports_status_created ON public_chat_reports(status, created_at DESC);
