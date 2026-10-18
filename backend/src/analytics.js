import { error, ok, parseJson, queryAll, queryOne, sha256 } from './core.js';
import { requireAdminPermission } from './admin/permissions.js';

const EVENT_NAMES = new Set([
  'page_view', 'screen_view', 'session_start', 'content_open', 'file_open',
  'search', 'operation_success', 'operation_failure', 'offline_use',
]);
const SECTIONS = new Set([
  'home', 'news', 'events', 'activities', 'achievements', 'materials', 'schedule',
  'student', 'tools', 'favorites', 'recent', 'notifications', 'eino', 'chat',
  'market', 'settings', 'more', 'media', 'website', 'other',
]);
const PLATFORMS = new Set(['app', 'website']);

/** Public event ingestion. Stores only a hash of a random, anonymous session token. */
export async function recordUsageEvent(ctx) {
  const body = await parseJson(ctx.request);
  const sessionId = typeof body?.sessionId === 'string' ? body.sessionId.trim() : '';
  const platform = String(body?.platform || '').trim().toLowerCase();
  const eventName = String(body?.eventName || '').trim().toLowerCase();
  const section = String(body?.section || 'other').trim().toLowerCase();
  const appVersion = typeof body?.appVersion === 'string' ? body.appVersion.trim().slice(0, 30) : null;

  if (!/^[a-zA-Z0-9_-]{16,128}$/.test(sessionId)) {
    return error('ANALYTICS_SESSION_INVALID', 'معرّف جلسة التحليلات غير صالح.', 400, ctx.requestId, ctx.cors);
  }
  if (!PLATFORMS.has(platform) || !EVENT_NAMES.has(eventName) || !SECTIONS.has(section)) {
    return error('ANALYTICS_EVENT_INVALID', 'نوع حدث التحليلات أو القسم غير مدعوم.', 400, ctx.requestId, ctx.cors);
  }

  const sessionHash = await sha256(`trinex-usage-v1:${sessionId}`);
  const recent = await queryOne(ctx.env,
    "SELECT COUNT(*) AS count FROM usage_events WHERE session_hash=? AND created_at >= datetime('now','-1 minute')",
    sessionHash);
  if (Number(recent?.count || 0) >= 60) {
    return error('ANALYTICS_RATE_LIMIT', 'تم تجاوز معدل تسجيل الأحداث لهذه الجلسة.', 429, ctx.requestId, ctx.cors);
  }

  await ctx.env.DB.prepare(`INSERT INTO usage_sessions (session_hash, platform, first_seen_at, last_seen_at)
    VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT(session_hash) DO UPDATE SET platform=excluded.platform, last_seen_at=CURRENT_TIMESTAMP`)
    .bind(sessionHash, platform).run();
  await ctx.env.DB.prepare(`INSERT INTO usage_events (id, session_hash, platform, event_name, section, app_version)
    VALUES (?, ?, ?, ?, ?, ?)`)
    .bind(crypto.randomUUID(), sessionHash, platform, eventName, section, appVersion || null).run();

  return ok(ctx, { recorded: true });
}

/** Admin-only aggregated reports; never returns session hashes or individual event rows. */
export async function adminUsageAnalytics(ctx) {
  const auth = await requireAdminPermission(ctx, 'superadmin.read');
  if (auth.response) return auth.response;
  const rawDays = Number.parseInt(ctx.url.searchParams.get('days') || '7', 10);
  const days = Number.isFinite(rawDays) ? Math.min(30, Math.max(1, rawDays)) : 7;
  const since = `-${days} days`;

  const [totalEvents, dau, wau, mau, newSessions, platforms, sections, eventTypes, trend, errors, resourceTotals, r2Storage, topRequests, topD1, topR2] = await Promise.all([
    queryOne(ctx.env, "SELECT COUNT(*) AS count FROM usage_events WHERE created_at >= datetime('now', ?)", since),
    queryOne(ctx.env, "SELECT COUNT(DISTINCT session_hash) AS count FROM usage_events WHERE created_at >= datetime('now','-1 day')"),
    queryOne(ctx.env, "SELECT COUNT(DISTINCT session_hash) AS count FROM usage_events WHERE created_at >= datetime('now','-7 days')"),
    queryOne(ctx.env, "SELECT COUNT(DISTINCT session_hash) AS count FROM usage_events WHERE created_at >= datetime('now','-30 days')"),
    queryOne(ctx.env, "SELECT COUNT(*) AS count FROM usage_sessions WHERE first_seen_at >= datetime('now', ?)", since),
    queryAll(ctx.env, "SELECT platform, COUNT(DISTINCT session_hash) AS count FROM usage_events WHERE created_at >= datetime('now', ?) GROUP BY platform ORDER BY count DESC", since),
    queryAll(ctx.env, "SELECT section, COUNT(*) AS count FROM usage_events WHERE created_at >= datetime('now', ?) GROUP BY section ORDER BY count DESC LIMIT 12", since),
    queryAll(ctx.env, "SELECT event_name AS eventName, COUNT(*) AS count FROM usage_events WHERE created_at >= datetime('now', ?) GROUP BY event_name ORDER BY count DESC", since),
    queryAll(ctx.env, "SELECT substr(created_at,1,10) AS date, COUNT(*) AS count FROM usage_events WHERE created_at >= datetime('now', ?) GROUP BY substr(created_at,1,10) ORDER BY date ASC", since),
    queryOne(ctx.env, "SELECT COUNT(*) AS count FROM usage_events WHERE event_name='operation_failure' AND created_at >= datetime('now', ?)", since),
    queryOne(ctx.env, `SELECT COALESCE(SUM(sample_weight),0) AS requests, COALESCE(SUM(duration_ms*sample_weight),0) AS durationMs,
      COALESCE(SUM(d1_operations*sample_weight),0) AS d1Operations, COALESCE(SUM(d1_rows_read*sample_weight),0) AS d1RowsRead,
      COALESCE(SUM(d1_rows_written*sample_weight),0) AS d1RowsWritten, COALESCE(SUM(r2_operations),0) AS r2Operations,
      COALESCE(SUM(r2_read_bytes),0) AS r2ReadBytes, COALESCE(SUM(r2_written_bytes),0) AS r2WrittenBytes,
      COALESCE(SUM(CASE WHEN status_code >= 500 THEN sample_weight ELSE 0 END),0) AS serverErrors
      FROM resource_usage_events WHERE created_at >= datetime('now', ?)`, since),
    queryOne(ctx.env, 'SELECT storage_bytes, class_a_used, quota_month FROM media_quota WHERE id=1'),
    queryAll(ctx.env, `SELECT route, SUM(sample_weight) AS count, COALESCE(SUM(duration_ms*sample_weight),0) AS durationMs FROM resource_usage_events
      WHERE created_at >= datetime('now', ?) GROUP BY route ORDER BY count DESC LIMIT 3`, since),
    queryAll(ctx.env, `SELECT route, SUM(d1_operations*sample_weight) AS count, SUM(d1_rows_read*sample_weight) AS rowsRead, SUM(d1_rows_written*sample_weight) AS rowsWritten
      FROM resource_usage_events WHERE created_at >= datetime('now', ?) GROUP BY route ORDER BY count DESC LIMIT 3`, since),
    queryAll(ctx.env, `SELECT route, SUM(r2_operations) AS count, SUM(r2_read_bytes+r2_written_bytes) AS bytes
      FROM resource_usage_events WHERE created_at >= datetime('now', ?) GROUP BY route HAVING SUM(r2_operations) > 0 ORDER BY count DESC LIMIT 3`, since),
  ]);

  return ok(ctx, {
    days,
    totalEvents: Number(totalEvents?.count || 0),
    activeSessions: {
      daily: Number(dau?.count || 0),
      weekly: Number(wau?.count || 0),
      monthly: Number(mau?.count || 0),
    },
    newSessions: Number(newSessions?.count || 0),
    failedOperations: Number(errors?.count || 0),
    platforms: platforms.map(row => ({ platform: row.platform, count: Number(row.count || 0) })),
    sections: sections.map(row => ({ section: row.section, count: Number(row.count || 0) })),
    eventTypes: eventTypes.map(row => ({ eventName: row.eventName, count: Number(row.count || 0) })),
    dailyTrend: trend.map(row => ({ date: row.date, count: Number(row.count || 0) })),
    resources: {
      period: {
        serverRequests: Number(resourceTotals?.requests || 0),
        averageResponseMs: Number(resourceTotals?.requests || 0) ? Math.round(Number(resourceTotals?.durationMs || 0) / Number(resourceTotals.requests)) : 0,
        serverErrors: Number(resourceTotals?.serverErrors || 0),
        d1Operations: Number(resourceTotals?.d1Operations || 0),
        d1RowsRead: Number(resourceTotals?.d1RowsRead || 0),
        d1RowsWritten: Number(resourceTotals?.d1RowsWritten || 0),
        r2Operations: Number(resourceTotals?.r2Operations || 0),
        r2ReadBytes: Number(resourceTotals?.r2ReadBytes || 0),
        r2WrittenBytes: Number(resourceTotals?.r2WrittenBytes || 0),
      },
      r2: {
        currentStorageBytes: Number(r2Storage?.storage_bytes || 0),
        monthlyClassARequests: Number(r2Storage?.class_a_used || 0),
        quotaMonth: r2Storage?.quota_month || null,
        configuredStorageLimitBytes: 6442450944,
      },
      topConsumers: {
        serverRequests: topRequests.map(r => ({ route: r.route, count: Number(r.count || 0), durationMs: Number(r.durationMs || 0) })),
        d1Operations: topD1.map(r => ({ route: r.route, count: Number(r.count || 0), rowsRead: Number(r.rowsRead || 0), rowsWritten: Number(r.rowsWritten || 0) })),
        r2Operations: topR2.map(r => ({ route: r.route, count: Number(r.count || 0), bytes: Number(r.bytes || 0) })),
      },
      notes: ['Server and D1 route totals use a 10% weighted sample to reduce D1 telemetry writes; R2-touching requests are all recorded.', 'R2 request and byte counts cover instrumented application paths; storage bytes come from the application media quota ledger, not Cloudflare billing exports.', 'Top consumers are normalized API routes, not individual students.'],
    },
    privacy: { individualEventsExposed: false, sessionIdsExposed: false, accountIdsStored: false, ipAddressesStored: false, userAgentsStored: false, contentBodiesStored: false, retentionDays: 90 },
  });
}
