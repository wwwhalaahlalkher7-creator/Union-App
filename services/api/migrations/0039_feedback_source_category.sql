-- Preserve the detailed Union-App feedback category while keeping the legacy
-- feedback_reports.category constraint compatible with the current moderation schema.
ALTER TABLE feedback_reports ADD COLUMN source_category TEXT NOT NULL DEFAULT 'other';
CREATE INDEX IF NOT EXISTS idx_feedback_source_category ON feedback_reports(source_category, created_at DESC);
