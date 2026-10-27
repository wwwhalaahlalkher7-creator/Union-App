-- Text chunks extracted from academic PDFs for department-scoped Eino retrieval.
CREATE TABLE IF NOT EXISTS eino_material_chunks (
  id TEXT PRIMARY KEY,
  material_id TEXT NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  department_id TEXT NOT NULL REFERENCES departments(id),
  semester_id TEXT,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  indexed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(material_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS idx_eino_chunks_scope
  ON eino_material_chunks(department_id, semester_id, material_id, chunk_index);
CREATE INDEX IF NOT EXISTS idx_eino_chunks_material
  ON eino_material_chunks(material_id, chunk_index);
