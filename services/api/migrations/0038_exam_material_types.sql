-- Separate exam papers from ordinary study material without title heuristics.
-- content_type is part of the canonical materials schema in 0001_initial.sql.
-- Existing D1 databases may already contain the column outside migration history,
-- so this migration only adds the supporting index and never re-adds the column.
CREATE INDEX IF NOT EXISTS idx_materials_type_subject_active
  ON materials(content_type, subject_id, active, sort_order, title);
