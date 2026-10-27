-- Stage 20: student email and registration index
ALTER TABLE students ADD COLUMN email TEXT;
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email, active);
