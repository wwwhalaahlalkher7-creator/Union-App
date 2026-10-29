PRAGMA foreign_keys = ON;

-- A student moderator is a student account with limited server-enforced
-- permission to hide public comments and replies. This does not grant staff access.
ALTER TABLE students ADD COLUMN is_moderator INTEGER NOT NULL DEFAULT 0
  CHECK (is_moderator IN (0, 1));

CREATE INDEX IF NOT EXISTS idx_students_moderator_active
  ON students(is_moderator, active);
