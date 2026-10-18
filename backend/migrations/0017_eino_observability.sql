-- Stage 7: privacy-preserving Eino observability.
-- Stores aggregate hourly counters only; never prompts, responses, IPs, student IDs, or provider keys.
CREATE TABLE IF NOT EXISTS eino_telemetry (
  id TEXT PRIMARY KEY,
  bucket_started_at TEXT NOT NULL,
  event_type TEXT NOT NULL,
  actor_type TEXT NOT NULL,
  event_count INTEGER NOT NULL DEFAULT 0,
  total_latency_ms INTEGER NOT NULL DEFAULT 0,
  last_event_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(bucket_started_at, event_type, actor_type)
);

CREATE INDEX IF NOT EXISTS idx_eino_telemetry_bucket
  ON eino_telemetry(bucket_started_at);
