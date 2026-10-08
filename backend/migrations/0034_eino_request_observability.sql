-- Eino operational request telemetry: intentionally excludes prompts, responses, student IDs, IPs and file contents.
CREATE TABLE IF NOT EXISTS eino_request_telemetry (
  id TEXT PRIMARY KEY,
  occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actor_type TEXT NOT NULL,
  capability TEXT NOT NULL,
  task TEXT,
  status TEXT NOT NULL,
  provider TEXT,
  model TEXT,
  latency_ms INTEGER NOT NULL DEFAULT 0,
  cost_units INTEGER NOT NULL DEFAULT 1,
  fallback INTEGER NOT NULL DEFAULT 0,
  error_code TEXT
);
CREATE INDEX IF NOT EXISTS idx_eino_request_telemetry_occurred ON eino_request_telemetry(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_eino_request_telemetry_provider ON eino_request_telemetry(provider, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_eino_request_telemetry_task ON eino_request_telemetry(task, occurred_at DESC);
