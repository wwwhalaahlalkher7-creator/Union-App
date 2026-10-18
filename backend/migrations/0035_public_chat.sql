-- Student-only public chat with report queue and soft moderation.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS public_chat_messages (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 1000),
  status TEXT NOT NULL DEFAULT 'visible' CHECK (status IN ('visible','hidden','deleted')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_public_chat_visible_created
  ON public_chat_messages(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_public_chat_student_created
  ON public_chat_messages(student_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public_chat_reports (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL REFERENCES public_chat_messages(id) ON DELETE CASCADE,
  reporter_student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('spam','harassment','inappropriate','other')),
  details TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','dismissed')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TEXT,
  reviewed_by TEXT,
  UNIQUE(message_id, reporter_student_id)
);
CREATE INDEX IF NOT EXISTS idx_public_chat_reports_status_created
  ON public_chat_reports(status, created_at DESC);
