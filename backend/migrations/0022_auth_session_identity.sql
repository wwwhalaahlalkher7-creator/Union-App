-- Stage 22 — keep student and staff sessions strictly separated.
-- Every session must belong to exactly one identity type.

CREATE TRIGGER IF NOT EXISTS sessions_identity_insert_guard
BEFORE INSERT ON sessions
WHEN ((NEW.student_id IS NULL) = (NEW.staff_user_id IS NULL))
BEGIN
  SELECT RAISE(ABORT, 'sessions must reference exactly one identity');
END;

CREATE TRIGGER IF NOT EXISTS sessions_identity_update_guard
BEFORE UPDATE OF student_id, staff_user_id ON sessions
WHEN ((NEW.student_id IS NULL) = (NEW.staff_user_id IS NULL))
BEGIN
  SELECT RAISE(ABORT, 'sessions must reference exactly one identity');
END;
