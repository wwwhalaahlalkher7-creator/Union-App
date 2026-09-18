-- Stage 24 — Unified media content and comment interactions.
-- News and activities can carry an optional ordered gallery; the first image
-- is used by list cards and the complete gallery is returned by detail APIs.
ALTER TABLE news ADD COLUMN images_json TEXT;
ALTER TABLE activities ADD COLUMN images_json TEXT;
ALTER TABLE activities ADD COLUMN category TEXT;

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  image_url TEXT,
  images_json TEXT,
  category TEXT,
  event_at TEXT,
  end_at TEXT,
  location TEXT,
  publisher TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  created_by TEXT REFERENCES staff_users(id),
  updated_by TEXT REFERENCES staff_users(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_events_status_date ON events(status, event_at);

CREATE INDEX IF NOT EXISTS idx_news_status_publish ON news(status, publish_at);
CREATE INDEX IF NOT EXISTS idx_activities_status_event ON activities(status, event_at);

CREATE TABLE IF NOT EXISTS comment_reactions (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id),
  comment_id TEXT NOT NULL REFERENCES comments(id),
  reaction TEXT NOT NULL DEFAULT 'like',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(student_id, comment_id)
);
CREATE INDEX IF NOT EXISTS idx_comment_reactions_comment ON comment_reactions(comment_id, reaction);
