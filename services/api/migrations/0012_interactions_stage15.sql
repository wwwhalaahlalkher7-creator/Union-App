CREATE TABLE IF NOT EXISTS interaction_rate_limits (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id),
  action TEXT NOT NULL,
  window_started_at TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  UNIQUE(student_id, action, window_started_at)
);
CREATE INDEX IF NOT EXISTS idx_interaction_rate_student_action ON interaction_rate_limits(student_id, action, window_started_at);
CREATE INDEX IF NOT EXISTS idx_comments_content_status_created ON comments(content_type, content_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_replies_comment_status_created ON comment_replies(comment_id, status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_reactions_content ON reactions(content_type, content_id, reaction);
