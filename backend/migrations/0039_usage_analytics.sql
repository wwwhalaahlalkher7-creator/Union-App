-- Privacy-preserving usage analytics. Only allowlisted event metadata is stored;
-- raw visitor tokens, IP addresses, user agents, content text and account IDs are never stored.
CREATE TABLE IF NOT EXISTS usage_sessions (
  session_hash TEXT PRIMARY KEY,
  platform TEXT NOT NULL CHECK (platform IN ('app', 'website')),
  first_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS usage_events (
  id TEXT PRIMARY KEY,
  session_hash TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('app', 'website')),
  event_name TEXT NOT NULL,
  section TEXT NOT NULL,
  app_version TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_usage_events_created_at ON usage_events(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_events_session_created ON usage_events(session_hash, created_at);
CREATE INDEX IF NOT EXISTS idx_usage_events_platform_created ON usage_events(platform, created_at);
CREATE INDEX IF NOT EXISTS idx_usage_events_section_created ON usage_events(section, created_at);
CREATE INDEX IF NOT EXISTS idx_usage_sessions_last_seen ON usage_sessions(last_seen_at);
