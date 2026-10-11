-- Link a public chat message to the message it replies to. Existing messages remain top-level.
ALTER TABLE public_chat_messages ADD COLUMN reply_to_message_id TEXT REFERENCES public_chat_messages(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_public_chat_reply_target ON public_chat_messages(reply_to_message_id, created_at);
