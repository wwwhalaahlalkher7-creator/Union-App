PRAGMA foreign_keys = ON;

-- General student chat. Reports are stored in the existing moderation inbox table.
CREATE TABLE IF NOT EXISTS public_chat_messages (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 1000),
  reply_to_message_id TEXT REFERENCES public_chat_messages(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'visible' CHECK (status IN ('visible','hidden','deleted')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_public_chat_visible_created ON public_chat_messages(status, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_public_chat_student_created ON public_chat_messages(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_public_chat_reply_target ON public_chat_messages(reply_to_message_id, created_at);

-- Per-student Eino chat history. Ownership is always enforced in the Worker.
CREATE TABLE IF NOT EXISTS eino_conversations (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_eino_conversations_student_updated ON eino_conversations(student_id, updated_at DESC);
CREATE TABLE IF NOT EXISTS eino_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES eino_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user','assistant')),
  content TEXT NOT NULL CHECK (length(content) BETWEEN 1 AND 4000),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_eino_messages_conversation_created ON eino_messages(conversation_id, created_at ASC, id ASC);

-- Privacy-preserving, anonymous app analytics: no account ids, raw session ids, IPs or content.
CREATE TABLE IF NOT EXISTS usage_sessions (
  session_hash TEXT PRIMARY KEY,
  platform TEXT NOT NULL CHECK (platform IN ('app','website')),
  first_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS usage_events (
  id TEXT PRIMARY KEY,
  session_hash TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('app','website')),
  event_name TEXT NOT NULL,
  section TEXT NOT NULL,
  app_version TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_usage_events_created_at ON usage_events(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_events_session_created ON usage_events(session_hash, created_at);
CREATE INDEX IF NOT EXISTS idx_usage_events_platform_created ON usage_events(platform, created_at);
CREATE INDEX IF NOT EXISTS idx_usage_events_section_created ON usage_events(section, created_at);
CREATE INDEX IF NOT EXISTS idx_usage_sessions_last_seen ON usage_sessions(last_seen_at);
