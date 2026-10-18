import { DurableObject } from 'cloudflare:workers';
import { processNotificationQueue } from './notifications.js';

const RESCHEDULE_PATH = '/reschedule';
const RETRY_DELAY_MS = 60_000;
const BACKLOG_DELAY_MS = 5_000;

/**
 * Event-driven scheduler for publication and notification dispatch.
 * A single Durable Object alarm represents the next due item; it replaces
 * per-minute database polling. Writes to relevant admin resources call
 * /reschedule so a newly-created or edited item updates the next alarm.
 */
export class TrinexScheduler extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== RESCHEDULE_PATH) {
      return new Response('Not found', { status: 404 });
    }
    try {
      await this.scheduleNextAlarm();
      return Response.json({ ok: true });
    } catch (error) {
      console.error('Unable to schedule next publication alarm', error);
      return Response.json({ ok: false }, { status: 500 });
    }
  }

  async alarm() {
    try {
      const now = new Date().toISOString();
      // Keep the same publication rules as the former cron worker.
      await Promise.all([
        this.env.DB.prepare("UPDATE news SET status='published', updated_at=CURRENT_TIMESTAMP WHERE status='draft' AND publish_at IS NOT NULL AND datetime(publish_at) <= CURRENT_TIMESTAMP").run(),
        this.env.DB.prepare("UPDATE achievements SET status='published', updated_at=CURRENT_TIMESTAMP WHERE status='draft' AND achieved_at IS NOT NULL AND datetime(achieved_at) <= CURRENT_TIMESTAMP").run(),
        this.env.DB.prepare("UPDATE announcements SET status='published', updated_at=CURRENT_TIMESTAMP WHERE status='draft' AND publish_at IS NOT NULL AND datetime(publish_at) <= CURRENT_TIMESTAMP AND (expires_at IS NULL OR datetime(expires_at) > CURRENT_TIMESTAMP)").run(),
      ]);

      // This function materializes due announcement targets before dispatching
      // the queue, preserving the previous sequence and idempotency guarantees.
      await processNotificationQueue(this.env);
      await this.scheduleNextAlarm();
    } catch (error) {
      console.error('Scheduled publication or notification processing failed', error);
      // A transient D1/FCM error must not silently lose the scheduler.
      await this.ctx.storage.setAlarm(Date.now() + RETRY_DELAY_MS);
    }
  }

  async scheduleNextAlarm() {
    const hasFcm = this.env.FCM_SERVICE_ACCOUNT_JSON ? 1 : 0;
    const result = await this.env.DB.prepare(`
      SELECT MIN(datetime(due_at)) AS due_at
      FROM (
        SELECT publish_at AS due_at
          FROM news
         WHERE status='draft' AND publish_at IS NOT NULL
        UNION ALL
        SELECT achieved_at AS due_at
          FROM achievements
         WHERE status='draft' AND achieved_at IS NOT NULL
        UNION ALL
        SELECT publish_at AS due_at
          FROM announcements
         WHERE status='draft' AND publish_at IS NOT NULL
           AND (expires_at IS NULL OR datetime(expires_at) > CURRENT_TIMESTAMP)
        UNION ALL
        SELECT COALESCE(a.publish_at, a.created_at) AS due_at
          FROM announcements a
         WHERE a.status='published'
           AND (a.expires_at IS NULL OR datetime(a.expires_at) > CURRENT_TIMESTAMP)
           AND NOT EXISTS (SELECT 1 FROM notification_targets nt WHERE nt.announcement_id=a.id)
           AND NOT EXISTS (SELECT 1 FROM notification_schedule_runs sr WHERE sr.announcement_id=a.id)
        UNION ALL
        SELECT q.scheduled_at AS due_at
          FROM notification_dispatch_queue q
          JOIN notification_targets nt ON nt.id=q.notification_target_id
          JOIN announcements a ON a.id=nt.announcement_id
         WHERE q.status='pending' AND q.attempts < 5
           AND (q.channel='in_app' OR ?=1)
           AND a.status='published'
           AND (a.publish_at IS NULL OR datetime(a.publish_at) <= CURRENT_TIMESTAMP)
           AND (a.expires_at IS NULL OR datetime(a.expires_at) > CURRENT_TIMESTAMP)
      )
      WHERE due_at IS NOT NULL
    `).bind(hasFcm).first();

    const dueText = result?.due_at;
    if (!dueText) {
      await this.ctx.storage.deleteAlarm();
      return;
    }

    // SQLite datetime() returns UTC text without a timezone suffix.
    const normalized = String(dueText).includes('T') ? String(dueText) : `${String(dueText).replace(' ', 'T')}Z`;
    const parsed = Date.parse(normalized);
    if (!Number.isFinite(parsed)) {
      console.error('Invalid scheduled timestamp from D1', dueText);
      await this.ctx.storage.setAlarm(Date.now() + RETRY_DELAY_MS);
      return;
    }

    const now = Date.now();
    const alarmAt = parsed <= now ? now + BACKLOG_DELAY_MS : parsed;
    await this.ctx.storage.setAlarm(alarmAt);
  }
}
