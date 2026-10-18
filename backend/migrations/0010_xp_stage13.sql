PRAGMA foreign_keys = ON;

CREATE INDEX IF NOT EXISTS idx_xp_events_student_type_created
  ON xp_events(student_id, event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_xp_events_student_source
  ON xp_events(student_id, source_id);
CREATE INDEX IF NOT EXISTS idx_student_badges_student_awarded
  ON student_badges(student_id, awarded_at DESC);

-- Stage 13 XP policy: milestones are awarded server-side only.
-- 25% = 10 XP, 50% = 10 XP, 75% = 15 XP, 100% = 25 XP.
-- A material can therefore award at most 60 XP through progress milestones.
