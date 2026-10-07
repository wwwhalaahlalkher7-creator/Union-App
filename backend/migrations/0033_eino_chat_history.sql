CREATE TABLE IF NOT EXISTS eino_conversations (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_eino_conversations_student_updated
  ON eino_conversations(student_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS eino_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('user','assistant')),
  content TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(conversation_id) REFERENCES eino_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_eino_messages_conversation_created
  ON eino_messages(conversation_id, created_at ASC);
