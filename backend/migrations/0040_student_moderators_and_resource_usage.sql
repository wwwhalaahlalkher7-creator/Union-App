-- Student moderation privileges and privacy-safe aggregate resource usage.
ALTER TABLE students ADD COLUMN is_moderator INTEGER NOT NULL DEFAULT 0 CHECK (is_moderator IN (0,1));
CREATE INDEX IF NOT EXISTS idx_students_moderator_active ON students(is_moderator, active);

CREATE TABLE IF NOT EXISTS resource_usage_events (
  id TEXT PRIMARY KEY,
  route TEXT NOT NULL,
  method TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  d1_operations INTEGER NOT NULL DEFAULT 0,
  d1_rows_read INTEGER NOT NULL DEFAULT 0,
  d1_rows_written INTEGER NOT NULL DEFAULT 0,
  r2_operations INTEGER NOT NULL DEFAULT 0,
  r2_read_bytes INTEGER NOT NULL DEFAULT 0,
  r2_written_bytes INTEGER NOT NULL DEFAULT 0,
  sample_weight INTEGER NOT NULL DEFAULT 1 CHECK (sample_weight >= 1),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_resource_usage_created ON resource_usage_events(created_at);
CREATE INDEX IF NOT EXISTS idx_resource_usage_route_created ON resource_usage_events(route, created_at);
