-- Normalize legacy notification timestamps to UTC. Old admin clients could store
-- Sudan wall-clock time without a timezone suffix; current APIs use UTC ISO.
-- Explicitly-zoned timestamps are converted as-is; naive wall times are UTC+02.
UPDATE announcements
   SET publish_at = CASE
     WHEN UPPER(publish_at) LIKE '%Z'
       OR (substr(publish_at, -6, 1) IN ('+', '-') AND substr(publish_at, -3, 1) = ':')
       THEN strftime('%Y-%m-%dT%H:%M:%fZ', datetime(publish_at))
     ELSE strftime('%Y-%m-%dT%H:%M:%fZ', datetime(replace(substr(publish_at, 1, 19), 'T', ' '), '-2 hours'))
   END
 WHERE publish_at IS NOT NULL
   AND datetime(publish_at) IS NOT NULL;

UPDATE announcements
   SET expires_at = CASE
     WHEN UPPER(expires_at) LIKE '%Z'
       OR (substr(expires_at, -6, 1) IN ('+', '-') AND substr(expires_at, -3, 1) = ':')
       THEN strftime('%Y-%m-%dT%H:%M:%fZ', datetime(expires_at))
     ELSE strftime('%Y-%m-%dT%H:%M:%fZ', datetime(replace(substr(expires_at, 1, 19), 'T', ' '), '-2 hours'))
   END
 WHERE expires_at IS NOT NULL
   AND datetime(expires_at) IS NOT NULL;

-- Manual announcements no longer use drafts. The only draft announcements
-- retained are auto-generated reviews linked to new/updated schedules/materials.
-- Future publish_at timestamps continue to schedule visibility and Push dispatch.
UPDATE announcements
   SET status = 'published', updated_at = CURRENT_TIMESTAMP
 WHERE status = 'draft'
   AND (content_type IS NULL OR content_type NOT IN ('schedule', 'material'));
