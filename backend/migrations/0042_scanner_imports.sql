-- Staged scanner imports. Source files are never stored in D1/R2; only reviewed
-- structured data and reversible change snapshots are retained.
CREATE TABLE IF NOT EXISTS import_operations (
  id TEXT PRIMARY KEY,
  import_type TEXT NOT NULL CHECK (import_type IN ('students','schedule')),
  department_id TEXT NOT NULL REFERENCES departments(id),
  semester_id TEXT NOT NULL REFERENCES semesters(id),
  status TEXT NOT NULL DEFAULT 'review' CHECK (status IN ('review','committed','rolled_back','expired','failed')),
  created_by TEXT REFERENCES staff_users(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TEXT NOT NULL,
  committed_at TEXT,
  rolled_back_at TEXT,
  reviewed_json TEXT NOT NULL DEFAULT '[]',
  summary_json TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_import_operations_created ON import_operations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_import_operations_status_expiry ON import_operations(status, expires_at);

CREATE TABLE IF NOT EXISTS import_operation_items (
  id TEXT PRIMARY KEY,
  operation_id TEXT NOT NULL REFERENCES import_operations(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('students','schedules')),
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('insert','replace')),
  before_json TEXT,
  after_json TEXT NOT NULL,
  rolled_back INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_import_operation_items_operation ON import_operation_items(operation_id);
