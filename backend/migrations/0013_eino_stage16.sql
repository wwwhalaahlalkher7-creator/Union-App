-- Stage 16: Eino gateway usage controls.
-- Stores counters only; no chat text or prompts are persisted.
CREATE TABLE IF NOT EXISTS eino_usage (
  id TEXT PRIMARY KEY,
  actor_key TEXT NOT NULL,
  window_started_at TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  last_request_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(actor_key, window_started_at)
);

CREATE INDEX IF NOT EXISTS idx_eino_usage_actor_window
  ON eino_usage(actor_key, window_started_at);
