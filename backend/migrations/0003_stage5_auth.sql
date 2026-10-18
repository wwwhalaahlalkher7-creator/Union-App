-- Stage 5 — production authentication foundation.
PRAGMA foreign_keys = ON;

ALTER TABLE students ADD COLUMN auth_secret_salt TEXT;
ALTER TABLE students ADD COLUMN auth_secret_algo TEXT NOT NULL DEFAULT 'legacy-sha256';
ALTER TABLE students ADD COLUMN failed_login_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE students ADD COLUMN locked_until TEXT;

ALTER TABLE staff_users ADD COLUMN password_hash TEXT;
ALTER TABLE staff_users ADD COLUMN password_salt TEXT;
ALTER TABLE staff_users ADD COLUMN password_algo TEXT NOT NULL DEFAULT 'pbkdf2-sha256';
ALTER TABLE staff_users ADD COLUMN failed_login_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE staff_users ADD COLUMN locked_until TEXT;
ALTER TABLE staff_users ADD COLUMN last_login_at TEXT;

CREATE INDEX IF NOT EXISTS idx_staff_email_active ON staff_users(email, active);
CREATE INDEX IF NOT EXISTS idx_sessions_staff_active ON sessions(staff_user_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_students_login_lock ON students(student_number, active, locked_until);

CREATE TABLE IF NOT EXISTS auth_audit_events (
  id TEXT PRIMARY KEY,
  actor_type TEXT NOT NULL,
  actor_id TEXT,
  event_type TEXT NOT NULL,
  ip_hash TEXT,
  user_agent_hash TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_auth_audit_actor_time ON auth_audit_events(actor_type, actor_id, created_at);

-- Every session must belong to exactly one identity type.
CREATE TRIGGER IF NOT EXISTS trg_sessions_identity_insert
BEFORE INSERT ON sessions
WHEN (NEW.student_id IS NULL AND NEW.staff_user_id IS NULL)
   OR (NEW.student_id IS NOT NULL AND NEW.staff_user_id IS NOT NULL)
BEGIN
  SELECT RAISE(ABORT, 'session must belong to exactly one identity');
END;

CREATE TRIGGER IF NOT EXISTS trg_sessions_identity_update
BEFORE UPDATE OF student_id, staff_user_id ON sessions
WHEN (NEW.student_id IS NULL AND NEW.staff_user_id IS NULL)
   OR (NEW.student_id IS NOT NULL AND NEW.staff_user_id IS NOT NULL)
BEGIN
  SELECT RAISE(ABORT, 'session must belong to exactly one identity');
END;
