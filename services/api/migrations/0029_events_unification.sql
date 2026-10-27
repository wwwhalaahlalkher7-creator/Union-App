-- Stage 29 — Unify public events around the former activities contract.
-- The legacy events table is intentionally discarded; the richer activities
-- shape becomes the single canonical events table.
PRAGMA foreign_keys = ON;

-- Remove interactions that belonged to the discarded legacy events records.
DELETE FROM comment_replies
WHERE comment_id IN (
  SELECT c.id FROM comments c
  WHERE c.content_type='event'
    AND c.content_id IN (SELECT id FROM events)
);
DELETE FROM comment_reactions
WHERE comment_id IN (
  SELECT c.id FROM comments c
  WHERE c.content_type='event'
    AND c.content_id IN (SELECT id FROM events)
);
DELETE FROM comments
WHERE content_type='event'
  AND content_id IN (SELECT id FROM events);
DELETE FROM reactions
WHERE content_type='event'
  AND content_id IN (SELECT id FROM events);

-- The old events table and its data are retired completely.
DROP TABLE IF EXISTS events;

-- Promote the former activities table (with its gallery/category/location/end date)
-- to the canonical events table.
ALTER TABLE activities RENAME TO events;

DROP INDEX IF EXISTS idx_activities_status_event;
DROP INDEX IF EXISTS idx_activities_event_end;
CREATE INDEX IF NOT EXISTS idx_events_status_date ON events(status, event_at);
CREATE INDEX IF NOT EXISTS idx_events_event_end ON events(event_at, end_at);

-- Existing activity interactions now point to the unified event content type.
UPDATE comments SET content_type='event' WHERE content_type='activity';
UPDATE reactions SET content_type='event' WHERE content_type='activity';
