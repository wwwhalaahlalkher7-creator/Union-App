-- Separate exam papers from ordinary study material without using title heuristics.
ALTER TABLE materials ADD COLUMN content_type TEXT NOT NULL DEFAULT 'material';
CREATE INDEX IF NOT EXISTS idx_materials_type_subject_active
  ON materials(content_type, subject_id, active, sort_order, title);
