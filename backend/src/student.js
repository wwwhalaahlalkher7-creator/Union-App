import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { auth, issueSession, staffAuth, studentAuth } from './auth.js';
export async function studentMe(ctx) {
  const a = await studentAuth(ctx);
  if (a.response) return a.response;
  const row = await queryOne(
    ctx.env,
    `SELECT st.id AS studentId, st.student_number AS studentNumber, st.full_name AS fullName, st.email, st.department_id AS departmentId, d.name_ar AS departmentName, st.current_semester_id AS currentSemesterId, se.name_ar AS semesterName FROM students st LEFT JOIN departments d ON d.id = st.department_id LEFT JOIN semesters se ON se.id = st.current_semester_id WHERE st.id = ? AND st.active = 1`,
    a.session.student_id,
  );
  return ok(ctx, row || sanitizeSession(a.session));
}

export async function updateStudentSemester(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  // The official current semester is an academic record owned by administration.
  // Students may browse other semesters through read-only GET endpoints.
  return error('ACADEMIC_RECORD_READ_ONLY', 'الفصل الدراسي الرسمي يُدار من لوحة التحكم. يمكنك اختيار فصل آخر للعرض دون تغيير السجل الأكاديمي.', 403, ctx.requestId, ctx.cors);
}

export async function studentStats(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const row = await queryOne(ctx.env, 'SELECT xp_total, level, updated_at FROM student_stats WHERE student_id = ?', a.session.student_id);
  return ok(ctx, row || { xp_total: 0, level: 1 });
}

export async function studentNotifications(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const rows = await queryAll(ctx.env, `SELECT nt.id, nt.announcement_id, nt.delivered_at, nt.read_at, a.title, a.body, a.type, a.publish_at, a.expires_at FROM notification_targets nt JOIN announcements a ON a.id = nt.announcement_id WHERE nt.student_id = ? AND a.status = 'published' AND (a.publish_at IS NULL OR a.publish_at <= CURRENT_TIMESTAMP) AND (a.expires_at IS NULL OR a.expires_at > CURRENT_TIMESTAMP) ORDER BY COALESCE(a.publish_at, a.created_at) DESC LIMIT ?`, a.session.student_id, limit);
  const unread = rows.filter(r => !r.read_at).length;
  return ok(ctx, rows, {count: rows.length, unread});
}

export async function studentNotificationRead(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  const ids = Array.isArray(body?.ids) ? body.ids.map(String).filter(Boolean).slice(0, 100) : [];
  if (!ids.length) return error('NOTIFICATION_IDS_REQUIRED', 'معرّفات الإشعارات مطلوبة.', 400, ctx.requestId, ctx.cors);
  const now = new Date().toISOString();
  const marks = ids.map(() => '?').join(',');
  const result = await ctx.env.DB.prepare(
    `UPDATE notification_targets
     SET read_at = COALESCE(read_at, ?)
     WHERE student_id = ? AND id IN (${marks})`
  ).bind(now, a.session.student_id, ...ids).run();
  return ok(ctx, {updated: Number(result.meta?.changes || 0)});
}

export async function registerNotificationDevice(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  const tokenValue = String(body?.token || '').trim();
  const platform = String(body?.platform || '').trim().toLowerCase();
  const appVersion = String(body?.appVersion || '').trim().slice(0, 64) || null;
  if (!tokenValue || tokenValue.length > 4096) return error('DEVICE_TOKEN_INVALID', 'رمز الجهاز غير صالح.', 400, ctx.requestId, ctx.cors);
  if (!['android','ios','web'].includes(platform)) return error('DEVICE_PLATFORM_INVALID', 'منصة الجهاز غير مدعومة.', 400, ctx.requestId, ctx.cors);
  const existing = await queryOne(ctx.env, 'SELECT id FROM notification_devices WHERE student_id = ? AND token = ?', a.session.student_id, tokenValue);
  const id = existing?.id || crypto.randomUUID();
  await ctx.env.DB.prepare(`INSERT INTO notification_devices (id, student_id, platform, token, app_version, active, last_seen_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT(student_id, token) DO UPDATE SET platform=excluded.platform, app_version=excluded.app_version, active=1, last_seen_at=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP`).bind(id, a.session.student_id, platform, tokenValue, appVersion).run();
  return ok(ctx, {id, registered: true});
}

export async function unregisterNotificationDevice(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  const tokenValue = String(body?.token || '').trim();
  if (!tokenValue) return error('DEVICE_TOKEN_REQUIRED', 'رمز الجهاز مطلوب.', 400, ctx.requestId, ctx.cors);
  await ctx.env.DB.prepare('UPDATE notification_devices SET active=0, updated_at=CURRENT_TIMESTAMP WHERE student_id=? AND token=?').bind(a.session.student_id, tokenValue).run();
  return ok(ctx, {unregistered: true});
}
