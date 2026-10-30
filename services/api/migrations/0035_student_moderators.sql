PRAGMA foreign_keys = ON;

-- is_moderator is part of the canonical students table definition in
-- 0001_initial.sql. Do not ALTER TABLE here: some existing D1 databases
-- already received this column outside migration history. Keeping this
-- migration additive and idempotent makes it safe for those databases.
CREATE INDEX IF NOT EXISTS idx_students_moderator_active
  ON students(is_moderator, active);
