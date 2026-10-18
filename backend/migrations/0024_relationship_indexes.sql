-- Stage 24 — relationship/query indexes.
-- Additive only. Historical migrations remain unchanged.
PRAGMA foreign_keys = ON;

CREATE INDEX IF NOT EXISTS idx_students_department_semester_active
  ON students(department_id, current_semester_id, active);
CREATE INDEX IF NOT EXISTS idx_subjects_department_semester_active
  ON subjects(department_id, semester_id, active, sort_order);
CREATE INDEX IF NOT EXISTS idx_materials_subject_active_sort
  ON materials(subject_id, active, sort_order);
CREATE INDEX IF NOT EXISTS idx_schedules_department_semester_active_time
  ON schedules(department_id, semester_id, active, day_of_week, start_time);
CREATE INDEX IF NOT EXISTS idx_comments_student_created
  ON comments(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comment_replies_comment_created
  ON comment_replies(comment_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_comment_reactions_student_comment
  ON comment_reactions(student_id, comment_id);
CREATE INDEX IF NOT EXISTS idx_reactions_student_content
  ON reactions(student_id, content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_eino_memories_student_created
  ON eino_memories(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_targets_student_read
  ON notification_targets(student_id, read_at, announcement_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_status_schedule
  ON notification_dispatch_queue(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_auth_audit_actor_created
  ON auth_audit_events(actor_type, actor_id, created_at DESC);
