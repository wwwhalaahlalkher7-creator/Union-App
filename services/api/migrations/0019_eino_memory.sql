-- Stage 8: Eino long-term memory index.
-- D1 stores ownership/consent/metadata; Chroma stores optional semantic vectors.
-- Do not store secrets or sensitive profile data in this table.
CREATE TABLE IF NOT EXISTS eino_memories (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  source TEXT NOT NULL DEFAULT 'user',
  chroma_id TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_eino_memories_student_updated
  ON eino_memories(student_id, updated_at DESC);
