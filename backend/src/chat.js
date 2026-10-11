import { ok, error, parseJson, queryAll, queryOne, clampInt } from './core.js';
import { studentAuth } from './auth.js';

const MAX_BODY = 1000;
const MESSAGE_SELECT = `SELECT m.id, m.student_id AS studentId, s.full_name AS fullName,
  s.department_id AS departmentId, d.name_ar AS departmentName,
  s.current_semester_id AS semesterId, se.name_ar AS semesterName,
  m.body, m.created_at AS createdAt, m.updated_at AS updatedAt
  FROM public_chat_messages m
  JOIN students s ON s.id=m.student_id
  LEFT JOIN departments d ON d.id=s.department_id
  LEFT JOIN semesters se ON se.id=s.current_semester_id`;

export async function publicChatMessages(ctx) {
  const auth = await studentAuth(ctx);
  if (auth.response) return auth.response;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const before = String(ctx.url.searchParams.get('before') || '').trim();
  let rows;
  if (before && before.length <= 128) {
    const cursor = await queryOne(ctx.env, 'SELECT created_at, id FROM public_chat_messages WHERE id=? AND status=\'visible\'', before);
    if (!cursor) return error('CHAT_CURSOR_INVALID', 'تعذر تحميل الرسائل السابقة.', 400, ctx.requestId, ctx.cors);
    rows = await queryAll(ctx.env, `${MESSAGE_SELECT} WHERE m.status='visible' AND (m.created_at < ? OR (m.created_at = ? AND m.id < ?)) ORDER BY m.created_at DESC, m.id DESC LIMIT ?`, cursor.created_at, cursor.created_at, cursor.id, limit);
  } else {
    rows = await queryAll(ctx.env, `${MESSAGE_SELECT} WHERE m.status='visible' ORDER BY m.created_at DESC, m.id DESC LIMIT ?`, limit);
  }
  rows.reverse();
  return ok(ctx, rows, { count: rows.length, limit, hasMore: rows.length === limit });
}

export async function createPublicChatMessage(ctx) {
  const auth = await studentAuth(ctx);
  if (auth.response) return auth.response;
  const body = await parseJson(ctx.request);
  const message = String(body?.body ?? '').replace(/\r\n?/g, '\n').trim();
  if (!message) return error('CHAT_MESSAGE_EMPTY', 'اكتب رسالة أولًا.', 400, ctx.requestId, ctx.cors);
  if (message.length > MAX_BODY) return error('CHAT_MESSAGE_TOO_LONG', 'الرسالة أطول من الحد المسموح.', 400, ctx.requestId, ctx.cors);
  if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(message)) return error('CHAT_MESSAGE_INVALID', 'الرسالة تحتوي على أحرف غير مدعومة.', 400, ctx.requestId, ctx.cors);

  // Lightweight per-student throttle. Five messages in 15 seconds is enough for
  // conversation while reducing accidental spam and automated flooding.
  const recent = await queryOne(ctx.env, `SELECT COUNT(*) AS count FROM public_chat_messages
    WHERE student_id=? AND created_at >= datetime('now','-15 seconds')`, auth.session.student_id);
  if (Number(recent?.count || 0) >= 5) return error('CHAT_RATE_LIMITED', 'تمهل قليلًا قبل إرسال رسائل أخرى.', 429, ctx.requestId, ctx.cors);

  const id = crypto.randomUUID();
  await ctx.env.DB.prepare('INSERT INTO public_chat_messages (id, student_id, body) VALUES (?, ?, ?)')
    .bind(id, auth.session.student_id, message).run();
  const row = await queryOne(ctx.env, `${MESSAGE_SELECT} WHERE m.id=? AND m.status='visible'`, id);
  return ok(ctx, row, null, 201);
}

export async function deleteOwnPublicChatMessage(ctx, id) {
  const auth = await studentAuth(ctx);
  if (auth.response) return auth.response;
  const result = await ctx.env.DB.prepare(`UPDATE public_chat_messages SET status='deleted', updated_at=CURRENT_TIMESTAMP
    WHERE id=? AND student_id=? AND status='visible'`).bind(id, auth.session.student_id).run();
  if (!result.meta?.changes) return error('CHAT_MESSAGE_NOT_FOUND', 'الرسالة غير موجودة أو لا يمكنك حذفها.', 404, ctx.requestId, ctx.cors);
  return ok(ctx, { id, deleted: true });
}

export async function reportPublicChatMessage(ctx, id) {
  const auth = await studentAuth(ctx);
  if (auth.response) return auth.response;
  const message = await queryOne(ctx.env, "SELECT id, student_id FROM public_chat_messages WHERE id=? AND status='visible'", id);
  if (!message) return error('CHAT_MESSAGE_NOT_FOUND', 'الرسالة غير موجودة أو لم تعد متاحة.', 404, ctx.requestId, ctx.cors);
  if (message.student_id === auth.session.student_id) return error('CHAT_REPORT_OWN_MESSAGE', 'لا يمكنك الإبلاغ عن رسالتك.', 400, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const reason = String(body?.reason || '').trim();
  const details = String(body?.details || '').trim().slice(0, 300) || null;
  if (!['spam','harassment','inappropriate','other'].includes(reason)) return error('CHAT_REPORT_REASON_INVALID', 'اختر سبب الإبلاغ.', 400, ctx.requestId, ctx.cors);
  const idReport = crypto.randomUUID();
  try {
    await ctx.env.DB.prepare('INSERT INTO public_chat_reports (id, message_id, reporter_student_id, reason, details) VALUES (?, ?, ?, ?, ?)')
      .bind(idReport, id, auth.session.student_id, reason, details).run();
  } catch (e) {
    if (/UNIQUE constraint failed/i.test(String(e?.message || e))) return error('CHAT_ALREADY_REPORTED', 'سبق أن أبلغت عن هذه الرسالة.', 409, ctx.requestId, ctx.cors);
    throw e;
  }
  return ok(ctx, { reported: true }, null, 201);
}
