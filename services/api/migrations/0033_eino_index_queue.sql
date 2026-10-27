-- Durable queue for automatic, incremental PDF indexing after Drive reconciliation.
CREATE TABLE IF NOT EXISTS eino_material_index_queue (
  material_id TEXT PRIMARY KEY REFERENCES materials(id) ON DELETE CASCADE,
  source_modified_at TEXT,
  status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','done','failed','cancelled')),
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  queued_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_eino_index_queue_status ON eino_material_index_queue(status, queued_at);
