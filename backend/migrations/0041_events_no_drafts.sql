-- Events/activities do not have a draft lifecycle. Their student-facing label is date-derived.
-- Normalize legacy rows, then prevent any backend write path from reintroducing draft status.
UPDATE events SET status = 'published' WHERE status IS NULL OR status <> 'published';

CREATE TRIGGER IF NOT EXISTS events_force_published_insert
AFTER INSERT ON events
WHEN NEW.status <> 'published'
BEGIN
  UPDATE events SET status = 'published' WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS events_force_published_update
AFTER UPDATE OF status ON events
WHEN NEW.status <> 'published'
BEGIN
  UPDATE events SET status = 'published' WHERE id = NEW.id;
END;
