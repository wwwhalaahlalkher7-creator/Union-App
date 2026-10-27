-- Stage 23 — Public content contract enrichment.
-- Preserve website information without reproducing the legacy Airtable shape.
PRAGMA foreign_keys = ON;

ALTER TABLE news ADD COLUMN category TEXT;
ALTER TABLE news ADD COLUMN publisher TEXT;

ALTER TABLE activities ADD COLUMN location TEXT;
ALTER TABLE activities ADD COLUMN publisher TEXT;
ALTER TABLE activities ADD COLUMN end_at TEXT;

ALTER TABLE achievements ADD COLUMN intro TEXT;
ALTER TABLE achievements ADD COLUMN highlights_title TEXT;
ALTER TABLE achievements ADD COLUMN highlights TEXT;
ALTER TABLE achievements ADD COLUMN badge TEXT;
ALTER TABLE achievements ADD COLUMN publisher TEXT;
ALTER TABLE achievements ADD COLUMN images_json TEXT;

CREATE INDEX IF NOT EXISTS idx_news_category_publish ON news(category, publish_at);
CREATE INDEX IF NOT EXISTS idx_activities_event_end ON activities(event_at, end_at);
CREATE INDEX IF NOT EXISTS idx_achievements_badge_date ON achievements(badge, achieved_at);
