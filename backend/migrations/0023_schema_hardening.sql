-- Stage 23 — schema hardening and relationship/query indexes.
-- This migration is additive only: it does not rename, drop, or rewrite
-- historical tables. Existing migration history remains the source of truth.
PRAGMA foreign_keys = ON;

-- Child-table indexes keep FK cleanup and common student/content queries fast.
CREATE INDEX IF NOT EXISTS idx_sessions_student_revoked
  ON sessions(student_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_staff_revoked
  ON sessions(staff_user_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_notification_targets_student
  ON notification_targets(student_id, announcement_id);
CREATE INDEX IF NOT EXISTS idx_notification_targets_announcement_student
  ON notification_targets(announcement_id, student_id);
CREATE INDEX IF NOT EXISTS idx_notification_devices_student
  ON notification_devices(student_id, active);
CREATE INDEX IF NOT EXISTS idx_notification_queue_target
  ON notification_dispatch_queue(notification_target_id, channel, status);
CREATE INDEX IF NOT EXISTS idx_material_progress_material_student
  ON material_progress(material_id, student_id);
CREATE INDEX IF NOT EXISTS idx_material_progress_events_student_material
  ON material_progress_events(student_id, material_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_material_progress_events_material_student
  ON material_progress_events(material_id, student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_badges_badge_student
  ON student_badges(badge_id, student_id);
CREATE INDEX IF NOT EXISTS idx_comment_replies_student
  ON comment_replies(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comment_reactions_student
  ON comment_reactions(student_id, comment_id);
CREATE INDEX IF NOT EXISTS idx_reactions_student
  ON reactions(student_id, content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_eino_memories_student
  ON eino_memories(student_id, id);

-- Content interaction lookups are deliberately aligned with the API's
-- content_type/content_id/status predicates.
CREATE INDEX IF NOT EXISTS idx_reactions_content_lookup
  ON reactions(content_type, content_id, reaction, student_id);
CREATE INDEX IF NOT EXISTS idx_comment_reactions_comment_student
  ON comment_reactions(comment_id, student_id);

-- Academic relationships are intentionally represented by normal foreign keys
-- plus application-level consistency checks. Composite cross-table CHECKs are
-- avoided so existing D1 data remains migration-safe.
