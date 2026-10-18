-- Content-linked notification drafts. Drafts remain unsent until an administrator approves them.
ALTER TABLE announcements ADD COLUMN notification_category TEXT NOT NULL DEFAULT 'general';
ALTER TABLE announcements ADD COLUMN content_type TEXT;
ALTER TABLE announcements ADD COLUMN content_id TEXT;
CREATE INDEX IF NOT EXISTS idx_announcements_content_link ON announcements(content_type, content_id, status);
