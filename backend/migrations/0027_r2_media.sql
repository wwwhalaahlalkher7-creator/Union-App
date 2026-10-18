-- Stage 25 — Private R2 media storage with an intentionally conservative free-tier guard.
CREATE TABLE IF NOT EXISTS media_assets (
  id TEXT PRIMARY KEY,
  object_key TEXT NOT NULL UNIQUE,
  content_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK(size_bytes > 0),
  sha256 TEXT NOT NULL,
  original_name TEXT,
  created_by TEXT REFERENCES staff_users(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  attached_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_media_assets_created ON media_assets(created_at DESC);

CREATE TABLE IF NOT EXISTS media_quota (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  storage_bytes INTEGER NOT NULL DEFAULT 0 CHECK(storage_bytes >= 0),
  class_a_used INTEGER NOT NULL DEFAULT 0 CHECK(class_a_used >= 0),
  quota_month TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT OR IGNORE INTO media_quota(id, storage_bytes, class_a_used, quota_month) VALUES(1, 0, 0, strftime('%Y-%m','now'));
