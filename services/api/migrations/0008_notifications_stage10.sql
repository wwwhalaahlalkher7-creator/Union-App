-- Stage 10 — Association notifications + push-ready device registry
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS notification_devices (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id),
  platform TEXT NOT NULL,
  token TEXT NOT NULL,
  app_version TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(student_id, token)
);

CREATE TABLE IF NOT EXISTS notification_dispatch_queue (
  id TEXT PRIMARY KEY,
  notification_target_id TEXT NOT NULL REFERENCES notification_targets(id),
  device_id TEXT REFERENCES notification_devices(id),
  channel TEXT NOT NULL DEFAULT 'in_app',
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  scheduled_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  delivered_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notification_devices_student_active ON notification_devices(student_id, active);
CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON notification_dispatch_queue(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_notification_targets_announcement ON notification_targets(announcement_id, delivered_at, read_at);
