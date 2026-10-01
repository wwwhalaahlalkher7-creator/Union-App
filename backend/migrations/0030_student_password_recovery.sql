-- Student password recovery: one-time six-digit codes.
CREATE TABLE IF NOT EXISTS password_reset_codes (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  used_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_password_reset_student_active
  ON password_reset_codes(student_id, used_at, expires_at);
