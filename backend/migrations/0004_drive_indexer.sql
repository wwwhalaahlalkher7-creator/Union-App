-- Stage 6 — Google Drive material index foundation.
PRAGMA foreign_keys = ON;

ALTER TABLE materials ADD COLUMN drive_parent_id TEXT;
ALTER TABLE materials ADD COLUMN drive_modified_at TEXT;
ALTER TABLE materials ADD COLUMN drive_web_view_url TEXT;
ALTER TABLE materials ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;
ALTER TABLE materials ADD COLUMN source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE materials ADD COLUMN last_synced_at TEXT;

CREATE INDEX IF NOT EXISTS idx_materials_subject_active_sort ON materials(subject_id, active, sort_order, title);
CREATE INDEX IF NOT EXISTS idx_materials_drive_parent ON materials(drive_parent_id, active);
CREATE INDEX IF NOT EXISTS idx_materials_source_active ON materials(source, active);
CREATE INDEX IF NOT EXISTS idx_subjects_semester_department ON subjects(semester_id, department_id, active, sort_order);

CREATE TABLE IF NOT EXISTS drive_sync_runs (
  id TEXT PRIMARY KEY,
  root_folder_id TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at TEXT,
  folders_seen INTEGER NOT NULL DEFAULT 0,
  files_seen INTEGER NOT NULL DEFAULT 0,
  materials_upserted INTEGER NOT NULL DEFAULT 0,
  materials_deactivated INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  triggered_by TEXT
);
CREATE INDEX IF NOT EXISTS idx_drive_sync_runs_started ON drive_sync_runs(started_at DESC);

CREATE TABLE IF NOT EXISTS drive_folder_index (
  id TEXT PRIMARY KEY,
  parent_id TEXT,
  folder_type TEXT NOT NULL,
  department_id TEXT,
  semester_id TEXT,
  subject_id TEXT,
  name TEXT NOT NULL,
  modified_at TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  last_synced_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_drive_folder_parent ON drive_folder_index(parent_id, active);
CREATE INDEX IF NOT EXISTS idx_drive_folder_semester ON drive_folder_index(semester_id, folder_type, active);
