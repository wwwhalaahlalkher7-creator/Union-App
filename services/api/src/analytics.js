import { ok, error, parseJson, queryAll, queryOne, sha256 } from './core.js';

const PLATFORMS = new Set(['app', 'website']);
const EVENT_NAMES = new Set(['session_start', 'screen_view', 'operation_failure']);
const SECTIONS = new Set(['home','media','materials','schedule','student','tools','recent','notifications','eino','chat','market','settings','more','website','other']);

export async function recordUsageEvent(ctx) {
  const body = await parseJson(ctx.request) || {};
  const sessionId = typeof body.sessionId === 'string' ? body.sessionId.trim() : '';
  const platform = String(body.platform || '').trim().toLowerCase();
  const eventName = String(body.eventName || '').trim().toLowerCase();
  const section = String(body.section || 'other').trim().toLowerCase();
  const appVersion = typeof body.appVersion === 'string' ? body.appVersion.trim().slice(0, 30) : null;
  if (!/^[a-zA-Z0-9_-]{16,128}$/.test(sessionId)) return error('ANALYTICS_SESSION_INVALID', 'معرّف جلسة التحليلات غير صالح.', 400, ctx.requestId, ctx.cors);
  if (!PLATFORMS.has(platform) || !EVENT_NAMES.has(eventName) || !SECTIONS.has(section)) return error('ANALYTICS_EVENT_INVALID', 'نوع حدث التحليلات أو القسم غير مدعوم.', 400, ctx.requestId, ctx.cors);
  const sessionHash = await sha256(`trinex-usage-v1:${sessionId}`);
  const recent = await queryOne(ctx.env, "SELECT COUNT(*) AS count FROM usage_events WHERE session_hash=? AND created_at >= datetime('now','-1 minute')", sessionHash);
  if (Number(recent?.count || 0) >= 60) return error('ANALYTICS_RATE_LIMIT', 'تم تجاوز معدل تسجيل الأحداث لهذه الجلسة.', 429, ctx.requestId, ctx.cors);
  await ctx.env.DB.prepare(`INSERT INTO usage_sessions (session_hash, platform, first_seen_at, last_seen_at)
    VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT(session_hash) DO UPDATE SET platform=excluded.platform, last_seen_at=CURRENT_TIMESTAMP`).bind(sessionHash, platform).run();
  await ctx.env.DB.prepare(`INSERT INTO usage_events (id, session_hash, platform, event_name, section, app_version)
    VALUES (?, ?, ?, ?, ?, ?)`).bind(crypto.randomUUID(), sessionHash, platform, eventName, section, appVersion || null).run();
  return ok(ctx, { recorded: true });
}
