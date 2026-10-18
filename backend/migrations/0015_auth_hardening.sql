-- Stage 2 — authentication hardening.
PRAGMA foreign_keys = ON;

-- Short-lived, hashed-IP buckets for login/refresh abuse protection.
-- IP addresses are never stored in plaintext.
CREATE TABLE IF NOT EXISTS auth_rate_limits (
  id TEXT PRIMARY KEY,
  ip_hash TEXT NOT NULL,
  action TEXT NOT NULL,
  window_started_at TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_window ON auth_rate_limits(action, window_started_at);
CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_ip ON auth_rate_limits(ip_hash, action, window_started_at);

-- Keep auth event volume bounded. The cleanup job can safely remove old buckets/events.
CREATE INDEX IF NOT EXISTS idx_auth_audit_events_created_at ON auth_audit_events(created_at);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at, refresh_expires_at, revoked_at);
