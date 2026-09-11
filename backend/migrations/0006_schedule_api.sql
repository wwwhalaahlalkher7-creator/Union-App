-- Stage 8: schedule query optimization and integrity helpers
CREATE INDEX IF NOT EXISTS idx_schedule_student_view
  ON schedules(department_id, semester_id, active, day_of_week, start_time);

CREATE INDEX IF NOT EXISTS idx_schedule_subject
  ON schedules(subject_id, active, day_of_week, start_time);
