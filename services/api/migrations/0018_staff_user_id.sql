-- Stage 18: staff login identity is a user_id, not an email address.
-- Email is retained as an optional contact field and is no longer used for login.
PRAGMA foreign_keys = OFF;

CREATE TABLE staff_users_v18 (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  email TEXT,
  display_name TEXT NOT NULL,
  role_id TEXT NOT NULL REFERENCES roles(id),
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  password_hash TEXT,
  password_salt TEXT,
  password_algo TEXT NOT NULL DEFAULT 'pbkdf2-sha256',
  failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT,
  last_login_at TEXT
);

-- Existing staff accounts, if any, keep their current email as their initial user_id.
-- This is only a migration bridge; future accounts may use any user_id string.
INSERT INTO staff_users_v18 (
  id, user_id, email, display_name, role_id, active, created_at, updated_at,
  password_hash, password_salt, password_algo, failed_login_attempts, locked_until, last_login_at
)
SELECT
  id, email, email, display_name, role_id, active, created_at, updated_at,
  password_hash, password_salt, password_algo, failed_login_attempts, locked_until, last_login_at
FROM staff_users;

DROP TABLE staff_users;
ALTER TABLE staff_users_v18 RENAME TO staff_users;

CREATE UNIQUE INDEX idx_staff_user_id_unique ON staff_users(lower(user_id));
CREATE INDEX idx_staff_user_id_active ON staff_users(user_id, active);
CREATE INDEX idx_staff_email_active ON staff_users(email, active);

PRAGMA foreign_keys = ON;
