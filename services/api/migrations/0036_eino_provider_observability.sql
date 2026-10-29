-- Privacy-preserving hourly Eino usage breakdown by capability/provider/model.
-- This table deliberately excludes prompts, replies, student IDs, IP addresses and API keys.
CREATE TABLE IF NOT EXISTS eino_provider_telemetry (
  id TEXT PRIMARY KEY,
  bucket_started_at TEXT NOT NULL,
  capability TEXT NOT NULL DEFAULT 'unknown',
  actor_type TEXT NOT NULL DEFAULT 'unknown',
  provider TEXT NOT NULL DEFAULT 'unknown',
  model TEXT NOT NULL DEFAULT 'unknown',
  status TEXT NOT NULL DEFAULT 'unknown',
  event_count INTEGER NOT NULL DEFAULT 0,
  total_latency_ms INTEGER NOT NULL DEFAULT 0,
  last_event_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(bucket_started_at, capability, actor_type, provider, model, status)
);

CREATE INDEX IF NOT EXISTS idx_eino_provider_telemetry_bucket
  ON eino_provider_telemetry(bucket_started_at);
CREATE INDEX IF NOT EXISTS idx_eino_provider_telemetry_capability
  ON eino_provider_telemetry(capability, provider, status, bucket_started_at);
