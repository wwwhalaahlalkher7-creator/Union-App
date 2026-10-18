-- Stage 26 — student identity integrity.
-- Registration claims an existing admin-created student record without
-- changing its academic ownership. Email is optional but unique when set.

CREATE UNIQUE INDEX IF NOT EXISTS idx_students_email_unique
ON students(lower(email))
WHERE email IS NOT NULL AND trim(email) <> '';

CREATE INDEX IF NOT EXISTS idx_students_auth_registration
ON students(student_number, active, auth_secret_hash);
