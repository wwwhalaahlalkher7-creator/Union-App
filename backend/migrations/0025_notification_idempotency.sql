-- Stage 25 — notification delivery idempotency.
-- Prevents duplicate queue rows when two admin send requests arrive concurrently.
PRAGMA foreign_keys = ON;

-- Clean historical duplicates before adding uniqueness. The oldest queue row is kept.
DELETE FROM notification_dispatch_queue
WHERE rowid NOT IN (
  SELECT MIN(rowid)
  FROM notification_dispatch_queue
  WHERE device_id IS NOT NULL
  GROUP BY notification_target_id, device_id, channel
)
AND device_id IS NOT NULL;

DELETE FROM notification_dispatch_queue
WHERE rowid NOT IN (
  SELECT MIN(rowid)
  FROM notification_dispatch_queue
  WHERE device_id IS NULL
  GROUP BY notification_target_id, channel
)
AND device_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notification_queue_push
  ON notification_dispatch_queue(notification_target_id, device_id, channel)
  WHERE device_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notification_queue_in_app
  ON notification_dispatch_queue(notification_target_id, channel)
  WHERE device_id IS NULL;
