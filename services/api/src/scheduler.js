import { DurableObject } from 'cloudflare:workers';
import { dispatchPushNotifications } from './notification_dispatch.js';

const RESCHEDULE_PATH = '/reschedule';
const RETRY_DELAY_MS = 60_000;
const BACKLOG_DELAY_MS = 5_000;

/**
 * Durable scheduler retained for the existing production TrinexScheduler
 * namespace. Keep this exported class name stable: deployed Durable Objects
 * are tied to the class name and their SQLite-backed storage must survive
 * Worker version updates.
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
      await this.env.DB.batch([
        this.env.DB.prepare("UPDATE news SET status='published', updated_at=CURRENT_TIMESTAMP WHERE status='draft' AND publish_at IS NOT NULL AND datetime(publish_at) <= CURRENT_TIMESTAMP"),
        this.env.DB.prepare("UPDATE achievements SET status='published', updated_at=CURRENT_TIMESTAMP WHERE status='draft' AND achieved_at IS NOT NULL AND datetime(achieved_at) <= CURRENT_TIMESTAMP"),
      ]);

      await this.materializeDueAnnouncements();
      const dispatch = await dispatchPushNotifications(this.env, 40);
      console.log(JSON.stringify({ event: 'scheduler_alarm', pushDispatch: dispatch }));
      await this.scheduleNextAlarm();
    } catch (error) {
      console.error('Scheduled publication or notification processing failed', error);
      // Preserve the alarm after transient D1/FCM failures; never silently stop.
      await this.ctx.storage.setAlarm(Date.now() + RETRY_DELAY_MS);
    }
  }

  async materializeDueAnnouncements() {
    const now = new Date().toISOString();
    const due = await this.env.DB.prepare(`
      SELECT a.id, a.target_department_id, a.target_semester_id
        FROM announcements a
       WHERE a.status='published'
         AND (a.publish_at IS NULL OR datetime(a.publish_at) <= datetime(?))
         AND (a.expires_at IS NULL OR datetime(a.expires_at) > datetime(?))
         AND NOT EXISTS (
           SELECT 1 FROM notification_schedule_runs sr WHERE sr.announcement_id=a.id
         )
       ORDER BY COALESCE(a.publish_at, a.created_at) ASC
       LIMIT 20
    `).bind(now, now).all();

    for (const announcement of (due.results || [])) {
      const departmentId = announcement.target_department_id || null;
      const semesterId = announcement.target_semester_id || null;

      await this.env.DB.prepare(`
        INSERT OR IGNORE INTO notification_targets (id, announcement_id, student_id)
        SELECT lower(hex(randomblob(16))), ?, s.id
          FROM students s
         WHERE s.active=1
           AND s.auth_secret_hash IS NOT NULL
           AND (? IS NULL OR s.department_id=?)
           AND (? IS NULL OR s.current_semester_id=?)
      `).bind(announcement.id, departmentId, departmentId, semesterId, semesterId).run();

      await this.env.DB.batch([
        this.env.DB.prepare(`
          INSERT OR IGNORE INTO notification_dispatch_queue (id, notification_target_id, device_id, channel)
          SELECT lower(hex(randomblob(16))), nt.id, nd.id, 'push'
            FROM notification_targets nt
            JOIN notification_devices nd ON nd.student_id=nt.student_id AND nd.active=1
           WHERE nt.announcement_id=?
             AND NOT EXISTS (
               SELECT 1 FROM notification_dispatch_queue q
                WHERE q.notification_target_id=nt.id AND q.device_id=nd.id AND q.channel='push'
             )
        `).bind(announcement.id),
        this.env.DB.prepare(`
          INSERT OR IGNORE INTO notification_dispatch_queue (id, notification_target_id, channel)
          SELECT lower(hex(randomblob(16))), nt.id, 'in_app'
            FROM notification_targets nt
           WHERE nt.announcement_id=?
             AND NOT EXISTS (
               SELECT 1 FROM notification_dispatch_queue q
                WHERE q.notification_target_id=nt.id AND q.device_id IS NULL AND q.channel='in_app'
             )
        `).bind(announcement.id),
      ]);

      const targetCount = await this.env.DB.prepare(
        'SELECT COUNT(*) AS count FROM notification_targets WHERE announcement_id=?',
      ).bind(announcement.id).first();
      await this.env.DB.prepare(`
        INSERT OR IGNORE INTO notification_schedule_runs (announcement_id, processed_at, target_count)
        VALUES (?, ?, ?)
      `).bind(announcement.id, now, Number(targetCount?.count || 0)).run();
    }
  }

  async scheduleNextAlarm() {
    const hasFcm = String(this.env.FCM_SERVICE_ACCOUNT_JSON || '').trim() ? 1 : 0;
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
          SELECT COALESCE(a.publish_at, a.created_at) AS due_at
            FROM announcements a
           WHERE a.status='published'
             AND (a.expires_at IS NULL OR datetime(a.expires_at) > CURRENT_TIMESTAMP)
             AND NOT EXISTS (
               SELECT 1 FROM notification_schedule_runs sr WHERE sr.announcement_id=a.id
             )
          UNION ALL
          SELECT q.scheduled_at AS due_at
            FROM notification_dispatch_queue q
            JOIN notification_targets nt ON nt.id=q.notification_target_id
            JOIN announcements a ON a.id=nt.announcement_id
           WHERE q.status='pending'
             AND q.channel='push'
             AND q.attempts < 8
             AND a.status='published'
             AND (a.publish_at IS NULL OR datetime(a.publish_at) <= CURRENT_TIMESTAMP)
             AND (a.expires_at IS NULL OR datetime(a.expires_at) > CURRENT_TIMESTAMP)
             AND ?=1
        )
       WHERE due_at IS NOT NULL
    `).bind(hasFcm).first();

    const dueText = result?.due_at;
    if (!dueText) {
      await this.ctx.storage.deleteAlarm();
      return;
    }

    // SQLite datetime() returns UTC text without a timezone suffix.
    const normalized = String(dueText).includes('T')
      ? String(dueText)
      : `${String(dueText).replace(' ', 'T')}Z`;
    const parsed = Date.parse(normalized);
    if (!Number.isFinite(parsed)) {
      console.error('Invalid scheduled timestamp from D1', dueText);
      await this.ctx.storage.setAlarm(Date.now() + RETRY_DELAY_MS);
      return;
    }

    const alarmAt = parsed <= Date.now() ? Date.now() + BACKLOG_DELAY_MS : parsed;
    await this.ctx.storage.setAlarm(alarmAt);
  }
}
