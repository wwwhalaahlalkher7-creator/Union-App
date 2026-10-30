import { ok, error, parseJson, queryAll, queryOne, clampInt } from './core.js';
import { studentAuth } from './auth.js';

const MAX_BODY = 1000;
const SELECT_MESSAGE = `SELECT m.id, m.student_id AS studentId, s.full_name AS fullName,
  s.department_id AS departmentId, d.name_ar AS departmentName,
  s.current_semester_id AS semesterId, se.name_ar AS semesterName,
  m.body, m.created_at AS createdAt, m.updated_at AS updatedAt,
  m.reply_to_message_id AS replyToMessageId,
  rm.body AS replyToBody, rs.full_name AS replyToFullName, rm.student_id AS replyToStudentId
  FROM public_chat_messages m JOIN students s ON s.id=m.student_id
  LEFT JOIN departments d ON d.id=s.department_id
  LEFT JOIN semesters se ON se.id=s.current_semester_id
  LEFT JOIN public_chat_messages rm ON rm.id=m.reply_to_message_id AND rm.status='visible'
  LEFT JOIN students rs ON rs.id=rm.student_id`;

export async function publicChatMessages(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const before = String(ctx.url.searchParams.get('before') || '').trim();
  let rows;
  if (before) {
    if (before.length > 128) return error('CHAT_CURSOR_INVALID', 'تعذر تحميل الرسائل السابقة.', 400, ctx.requestId, ctx.cors);
    const cursor = await queryOne(ctx.env, "SELECT created_at, id FROM public_chat_messages WHERE id=? AND status='visible'", before);
    if (!cursor) return error('CHAT_CURSOR_INVALID', 'تعذر تحميل الرسائل السابقة.', 400, ctx.requestId, ctx.cors);
    rows = await queryAll(ctx.env, `${SELECT_MESSAGE} WHERE m.status='visible' AND (m.created_at < ? OR (m.created_at = ? AND m.id < ?)) ORDER BY m.created_at DESC, m.id DESC LIMIT ?`, cursor.created_at, cursor.created_at, cursor.id, limit);
  } else {
    rows = await queryAll(ctx.env, `${SELECT_MESSAGE} WHERE m.status='visible' ORDER BY m.created_at DESC, m.id DESC LIMIT ?`, limit);
  }
  rows.reverse();
  return ok(ctx, rows, { count: rows.length, limit, hasMore: rows.length === limit });
}

export async function createPublicChatMessage(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request) || {};
  const message = String(body.body ?? '').replace(/\r\n?/g, '\n').trim();
  const replyTo = String(body.replyToMessageId ?? '').trim();
  if (!message) return error('CHAT_MESSAGE_EMPTY', 'اكتب رسالة أولًا.', 400, ctx.requestId, ctx.cors);
  if (message.length > MAX_BODY || /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(message)) return error('CHAT_MESSAGE_INVALID', 'الرسالة أطول من الحد المسموح أو تحتوي محارف غير مدعومة.', 400, ctx.requestId, ctx.cors);
  if (replyTo) {
    if (replyTo.length > 128) return error('CHAT_REPLY_TARGET_INVALID', 'الرسالة المراد الرد عليها غير صالحة.', 400, ctx.requestId, ctx.cors);
    const parent = await queryOne(ctx.env, "SELECT id FROM public_chat_messages WHERE id=? AND status='visible'", replyTo);
    if (!parent) return error('CHAT_REPLY_TARGET_NOT_FOUND', 'الرسالة المراد الرد عليها لم تعد متاحة.', 404, ctx.requestId, ctx.cors);
  }
  const recent = await queryOne(ctx.env, "SELECT COUNT(*) AS count FROM public_chat_messages WHERE student_id=? AND created_at >= datetime('now','-15 seconds')", a.session.student_id);
  if (Number(recent?.count || 0) >= 5) return error('CHAT_RATE_LIMITED', 'تمهل قليلًا قبل إرسال رسائل أخرى.', 429, ctx.requestId, ctx.cors);
  const id = crypto.randomUUID();
  await ctx.env.DB.prepare('INSERT INTO public_chat_messages (id, student_id, body, reply_to_message_id) VALUES (?, ?, ?, ?)')
    .bind(id, a.session.student_id, message, replyTo || null).run();
  const row = await queryOne(ctx.env, `${SELECT_MESSAGE} WHERE m.id=? AND m.status='visible'`, id);
  return ok(ctx, row, null, 201);
}

export async function deleteOwnPublicChatMessage(ctx, id) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const moderator = Number(a.session.is_moderator || 0) === 1;
  const result = moderator
    ? await ctx.env.DB.prepare("UPDATE public_chat_messages SET status='deleted', updated_at=CURRENT_TIMESTAMP WHERE id=? AND status='visible'").bind(id).run()
    : await ctx.env.DB.prepare("UPDATE public_chat_messages SET status='deleted', updated_at=CURRENT_TIMESTAMP WHERE id=? AND student_id=? AND status='visible'").bind(id, a.session.student_id).run();
  if (!result.meta?.changes) return error('CHAT_MESSAGE_NOT_FOUND', 'الرسالة غير موجودة أو لا يمكنك حذفها.', 404, ctx.requestId, ctx.cors);
  if (moderator) {
    await ctx.env.DB.prepare('INSERT INTO audit_logs (id,actor_type,actor_id,action,resource_type,resource_id,metadata_json) VALUES (?,?,?,?,?,?,?)')
      .bind(crypto.randomUUID(), 'student_moderator', a.session.student_id, 'moderator_delete', 'public_chat_message', id, '{}').run();
  }
  return ok(ctx, { id, deleted: true, moderated: moderator });
}

export async function reportPublicChatMessage(ctx, id) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const message = await queryOne(ctx.env, "SELECT m.id, m.student_id, m.body, s.full_name FROM public_chat_messages m JOIN students s ON s.id=m.student_id WHERE m.id=? AND m.status='visible'", id);
  if (!message) return error('CHAT_MESSAGE_NOT_FOUND', 'الرسالة غير موجودة أو لم تعد متاحة.', 404, ctx.requestId, ctx.cors);
  if (message.student_id === a.session.student_id) return error('CHAT_REPORT_OWN_MESSAGE', 'لا يمكنك الإبلاغ عن رسالتك.', 400, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request) || {};
  const reason = String(body.reason || '').trim();
  const details = String(body.details || '').trim().slice(0, 300) || null;
  if (!['spam','harassment','inappropriate','other'].includes(reason)) return error('CHAT_REPORT_REASON_INVALID', 'اختر سبب الإبلاغ.', 400, ctx.requestId, ctx.cors);
  const duplicate = await queryOne(ctx.env, "SELECT id FROM chat_reports WHERE reporter_student_id=? AND reported_message_id=? AND status IN ('open','reviewed') LIMIT 1", a.session.student_id, id);
  if (duplicate) return error('CHAT_ALREADY_REPORTED', 'سبق أن أبلغت عن هذه الرسالة.', 409, ctx.requestId, ctx.cors);
  const reportId = crypto.randomUUID();
  await ctx.env.DB.prepare(`INSERT INTO chat_reports (id, reporter_student_id, reported_message_id, author_name, message_body, reason, screen, status, message_status)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'open', 'visible')`)
    .bind(reportId, a.session.student_id, id, message.full_name, message.body, `${reason}${details ? `: ${details}` : ''}`, 'general_chat').run();
  return ok(ctx, { reported: true }, null, 201);
}
