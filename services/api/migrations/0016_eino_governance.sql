-- Stage 6 security: atomic Eino governance counters.
-- No prompts, responses, IPs, or student profile data are stored here.
CREATE TABLE IF NOT EXISTS eino_quota_usage (
  id TEXT PRIMARY KEY,
  bucket_type TEXT NOT NULL,
  scope_key TEXT NOT NULL,
  bucket_started_at TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  last_request_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(bucket_type, scope_key, bucket_started_at)
);

CREATE INDEX IF NOT EXISTS idx_eino_quota_scope_bucket
  ON eino_quota_usage(scope_key, bucket_type, bucket_started_at);
