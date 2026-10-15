import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
  normalizeEmail, isValidEmail,
} from './core.js';
import { recordAuthEvent } from './auth.js';
import { deleteOwnedMediaUrls, extractMediaUrlsFromRow, markOwnedMediaAttached } from './media.js';
import { deleteDriveFilesViaAppsScript } from './drive.js';
import { createOrRefreshContentNotificationDraft } from './notification_drafts.js';
import { ocrSpaceFromFile } from './providers/ocr_space.js';

import { ADMIN_ROLE_IDS, ADMIN_FIELDS, CONTENT_STATUS_VALUES, CONTENT_TABLES, CONTENT_UPDATED_BY_TABLES, ADMIN_SELECT_COLUMNS } from './admin/config.js';
import { hasAdminPermission, requireAdminPermission } from './admin/permissions.js';
export { requireAdminPermission } from './admin/permissions.js';

export async function adminChatReports(ctx) {
  const a = await requireAdminPermission(ctx, 'moderation.read'); if (a.response) return a.response;
  const status = String(ctx.url.searchParams.get('status') || 'open');
  if (!['open','reviewed','dismissed'].includes(status)) return error('STATUS_INVALID','حالة البلاغ غير صالحة.',400,ctx.requestId,ctx.cors);
  const limit = clampInt(ctx.url.searchParams.get('limit'),50,1,100);
  const rows = await queryAll(ctx.env, `SELECT r.id, r.message_id AS messageId, r.reason, r.details, r.status,
    r.created_at AS createdAt, r.reviewed_at AS reviewedAt,
    m.body AS messageBody, m.status AS messageStatus, author.full_name AS authorName,
    reporter.full_name AS reporterName
    FROM public_chat_reports r
    JOIN public_chat_messages m ON m.id=r.message_id
    JOIN students author ON author.id=m.student_id
    JOIN students reporter ON reporter.id=r.reporter_student_id
    WHERE r.status=? ORDER BY r.created_at DESC LIMIT ?`, status, limit);
  return ok(ctx, rows, {count:rows.length, status});
}

export async function adminChatReportUpdate(ctx, id) {
  const a = await requireAdminPermission(ctx, 'moderation.write'); if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  const status = String(body?.status || '').trim();
  const messageStatus = body?.messageStatus == null ? null : String(body.messageStatus).trim();
  if (!['reviewed','dismissed'].includes(status)) return error('STATUS_INVALID','حالة البلاغ غير صالحة.',400,ctx.requestId,ctx.cors);
  if (messageStatus != null && !['visible','hidden','deleted'].includes(messageStatus)) return error('CHAT_MESSAGE_STATUS_INVALID','حالة الرسالة غير صالحة.',400,ctx.requestId,ctx.cors);
  const report = await queryOne(ctx.env, 'SELECT id, message_id FROM public_chat_reports WHERE id=?', id);
  if (!report) return error('CHAT_REPORT_NOT_FOUND','البلاغ غير موجود.',404,ctx.requestId,ctx.cors);
  await ctx.env.DB.prepare('UPDATE public_chat_reports SET status=?, reviewed_at=CURRENT_TIMESTAMP, reviewed_by=? WHERE id=?')
    .bind(status, a.session.staff_user_id, id).run();
  if (messageStatus != null) {
    await ctx.env.DB.prepare('UPDATE public_chat_messages SET status=?, updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .bind(messageStatus, report.message_id).run();
  }
  await writeAudit(ctx, a.session.staff_user_id, 'chat_report_review', 'public_chat_report', id, {status, messageStatus});
  return ok(ctx, {id, status, messageStatus});
}

export async function adminModerationComments(ctx) { const a=await requireAdminPermission(ctx, 'moderation.read'); if(a.response) return a.response; const status=String(ctx.url.searchParams.get('status')||'visible'); if(!['visible','hidden','deleted'].includes(status)) return error('STATUS_INVALID','حالة الإشراف غير صالحة.',400,ctx.requestId,ctx.cors); const limit=clampInt(ctx.url.searchParams.get('limit'),50,1,100); const rows=await queryAll(ctx.env,"SELECT c.*,s.full_name,s.student_number, (SELECT COUNT(*) FROM comment_replies cr WHERE cr.comment_id=c.id AND cr.status='visible') AS reply_count FROM comments c JOIN students s ON s.id=c.student_id WHERE c.status=? ORDER BY c.created_at DESC LIMIT ?",status,limit); return ok(ctx,rows,{count:rows.length}); }

export async function adminModerationComment(ctx,id) { const a=await requireAdminPermission(ctx, 'moderation.write'); if(a.response) return a.response; const body=await parseJson(ctx.request); const status=String(body?.status||'').trim(); if(!['visible','hidden','deleted'].includes(status)) return error('STATUS_INVALID','حالة الإشراف غير صالحة.',400,ctx.requestId,ctx.cors); const r=await ctx.env.DB.prepare('UPDATE comments SET status=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(status,id).run(); if(!r.meta?.changes) return error('COMMENT_NOT_FOUND','التعليق غير موجود.',404,ctx.requestId,ctx.cors); await writeAudit(ctx,a.session.staff_user_id,'status_update','comment',id,{status}); return ok(ctx,{id,status}); }

export async function adminModerationReplies(ctx) {
  const a = await requireAdminPermission(ctx, 'moderation.read'); if (a.response) return a.response;
  const status = String(ctx.url.searchParams.get('status') || 'visible');
  if (!['visible','hidden','deleted'].includes(status)) return error('STATUS_INVALID','حالة الإشراف غير صالحة.',400,ctx.requestId,ctx.cors);
  const limit = clampInt(ctx.url.searchParams.get('limit'),50,1,100);
  const rows = await queryAll(ctx.env, "SELECT r.*, s.full_name, c.body AS comment_body, c.content_type, c.content_id FROM comment_replies r JOIN students s ON s.id=r.student_id JOIN comments c ON c.id=r.comment_id WHERE r.status=? ORDER BY r.created_at DESC LIMIT ?", status, limit);
  return ok(ctx, rows, {count:rows.length});
}

export async function adminModerationReply(ctx,id) {
  const a = await requireAdminPermission(ctx, 'moderation.write'); if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  const status = String(body?.status || '').trim();
  if (!['visible','hidden','deleted'].includes(status)) return error('STATUS_INVALID','حالة الإشراف غير صالحة.',400,ctx.requestId,ctx.cors);
  const r = await ctx.env.DB.prepare('UPDATE comment_replies SET status=? WHERE id=?').bind(status,id).run();
  if (!r.meta?.changes) return error('REPLY_NOT_FOUND','الرد غير موجود.',404,ctx.requestId,ctx.cors);
  await writeAudit(ctx,a.session.staff_user_id,'status_update','comment_reply',id,{status});
  return ok(ctx,{id,status});
}

export async function adminDeleteReply(ctx,id) {
  const a = await requireAdminPermission(ctx, 'moderation.write'); if (a.response) return a.response;
  const r = await ctx.env.DB.prepare('DELETE FROM comment_replies WHERE id=?').bind(id).run();
  if (!r.meta?.changes) return error('REPLY_NOT_FOUND','الرد غير موجود.',404,ctx.requestId,ctx.cors);
  await writeAudit(ctx,a.session.staff_user_id,'delete','comment_reply',id,{mode:'hard_delete'});
  return ok(ctx,{deleted:true,id,mode:'hard_delete'});
}


export async function adminSetStudentModerator(ctx, id) {
  const a = await requireAdminPermission(ctx, 'academic.write');
  if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  if (typeof body?.isModerator !== 'boolean') return error('STUDENT_MODERATOR_VALUE_INVALID', 'قيمة منصب مشرف الطالب غير صالحة.', 400, ctx.requestId, ctx.cors);
  const result = await ctx.env.DB.prepare('UPDATE students SET is_moderator=?, updated_at=CURRENT_TIMESTAMP WHERE id=? AND active=1')
    .bind(body.isModerator ? 1 : 0, id).run();
  if (!result.meta?.changes) return error('STUDENT_NOT_FOUND_OR_INACTIVE', 'الطالب غير موجود أو حسابه موقوف.', 404, ctx.requestId, ctx.cors);
  await writeAudit(ctx, a.session.staff_user_id, body.isModerator ? 'grant_student_moderator' : 'revoke_student_moderator', 'students', id, { isModerator: body.isModerator });
  return ok(ctx, { id, isModerator: body.isModerator });
}

export async function adminDashboardOverview(ctx) {
  const a = await adminRouteAuthOnly(ctx, 'dashboard.read');
  if (a.response) return a.response;

  const [students, activeStudents, staff, activeStaff, news, materials, comments, announcements] = await Promise.all([
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM students'),
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM students WHERE active = 1'),
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM staff_users'),
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM staff_users WHERE active = 1'),
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM news'),
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM materials WHERE active = 1'),
    queryOne(ctx.env, "SELECT COUNT(*) AS count FROM comments WHERE status = 'visible'"),
    queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM announcements'),
  ]);

  return ok(ctx, {
    students: Number(students?.count || 0),
    activeStudents: Number(activeStudents?.count || 0),
    staff: Number(staff?.count || 0),
    activeStaff: Number(activeStaff?.count || 0),
    news: Number(news?.count || 0),
    materials: Number(materials?.count || 0),
    visibleComments: Number(comments?.count || 0),
    announcements: Number(announcements?.count || 0),
  });
}

export async function adminRoute(ctx) {
  const a = await requireAdminPermission(ctx, adminPermission(ctx.path, ctx.request.method));
  if (a.response) return a.response;

  const parts = ctx.path.split('/').filter(Boolean);
  const resource = parts[1] || '';
  const id = parts[2] || null;
  if (resource === 'audit-logs' && ctx.request.method === 'GET') return adminAuditLogs(ctx);
  if (resource === 'imports') return adminImportsRoute(ctx, parts.slice(2), a.session.staff_user_id, a.session.staff_role_id);
  if (resource === 'settings') return adminSettings(ctx, id);
  if (resource === 'staff') return adminStaff(ctx, id, a.session.staff_user_id);
  if (resource === 'notifications' && parts[2] === 'send' && ctx.request.method === 'POST') return adminNotificationSend(ctx, a.session.staff_user_id);
  if (resource === 'drive') return error('DRIVE_ROUTE_NOT_FOUND', 'مسار Drive غير معروف.', 404, ctx.requestId, ctx.cors);
  const table = adminResourceTable(resource);
  if (!table) return error('ADMIN_RESOURCE_NOT_FOUND', 'وحدة الإدارة غير معروفة.', 404, ctx.requestId, ctx.cors);
  return adminCrud(ctx, table, id, a.session.staff_user_id);
}

export function adminPermission(path, method) {
  if (path.includes('/dashboard/')) return 'dashboard.read';
  if (path.includes('/security/auth-events') || path.includes('/security/eino-monitor')) return 'superadmin.read';
  if (path.includes('/security/eino-usage')) return 'dashboard.read';
  if (path.includes('/staff')) return method === 'GET' ? 'superadmin.read' : 'superadmin.write';
  if (path.includes('/settings')) return method === 'GET' ? 'superadmin.read' : 'superadmin.write';
  if (path.includes('/audit-logs')) return method === 'GET' ? 'superadmin.read' : 'superadmin.write';
  if (path.includes('/imports')) return method === 'GET' ? 'superadmin.read' : 'academic.write';
  if (path.includes('/drive')) return method === 'GET' ? 'academic.read' : 'academic.write';
  if (path.includes('/notifications') || path.includes('/announcements')) return method === 'GET' ? 'notifications.read' : 'notifications.write';
  if (path.includes('/students') || path.includes('/subjects') || path.includes('/materials') || path.includes('/schedule')) return method === 'GET' ? 'academic.read' : 'academic.write';
  if (path.includes('/comments') || path.includes('/moderation')) return method === 'GET' ? 'moderation.read' : 'moderation.write';
  return method === 'GET' ? 'content.read' : 'content.write';
}

export function adminResourceTable(resource) {
  const map = { news:'news', announcements:'announcements', activities:'events', achievements:'achievements', subjects:'subjects', materials:'materials', schedule:'schedules', schedules:'schedules', students:'students', comments:'comments' };
  return map[resource] || null;
}

export function cleanAdminPayload(table, body) {
  const out = {};
  const aliases = {
    students: { studentNumber: 'student_number', studentId: 'student_number', fullName: 'full_name', emailAddress: 'email', departmentId: 'department_id', department: 'department_id', currentSemesterId: 'current_semester_id', semesterId: 'current_semester_id', semester: 'current_semester_id' },
    subjects: { semesterId: 'semester_id', departmentId: 'department_id', name: 'name_ar', nameAr: 'name_ar', nameEn: 'name_en', sortOrder: 'sort_order' },
    schedules: { semesterId: 'semester_id', departmentId: 'department_id', dayOfWeek: 'day_of_week', startTime: 'start_time', endTime: 'end_time', subjectId: 'subject_id', lecturer: 'lecturer' },
    materials: { subjectId: 'subject_id', driveFileId: 'drive_file_id', driveUrl: 'drive_url', driveWebViewUrl: 'drive_web_view_url', mimeType: 'mime_type', sizeBytes: 'size_bytes', sortOrder: 'sort_order', driveParentId: 'drive_parent_id', driveModifiedAt: 'drive_modified_at' },
  };
  const source = body || {};
  if (table === 'students' && Object.prototype.hasOwnProperty.call(source, 'email')) {
    source.email = source.email === '' || source.email == null ? null : normalizeEmail(source.email);
  }
  for (const key of ADMIN_FIELDS[table] || []) {
    if (Object.prototype.hasOwnProperty.call(source, key)) out[key] = source[key] === '' ? null : source[key];
  }
  for (const [alias, key] of Object.entries(aliases[table] || {})) {
    if (out[key] === undefined && Object.prototype.hasOwnProperty.call(source, alias)) out[key] = source[alias] === '' ? null : source[alias];
  }
  if (table === 'students' && out.email !== undefined && out.email !== null) out.email = normalizeEmail(out.email);
  return out;
}

export async function validateAcademicReferences(ctx, table, fields, existing = null) {
  const value = (key) => fields[key] !== undefined ? fields[key] : existing?.[key];

  if (table === 'students') {
    if (value('department_id')) {
      const row = await queryOne(ctx.env, 'SELECT id FROM departments WHERE id=? AND active=1', value('department_id'));
      if (!row) return error('DEPARTMENT_NOT_FOUND', 'القسم الأكاديمي غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);
    }
    if (value('current_semester_id')) {
      const row = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE id=? AND active=1', value('current_semester_id'));
      if (!row) return error('SEMESTER_NOT_FOUND', 'الفصل الدراسي غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);
    }
  }

  if (table === 'subjects') {
    const [department, semester] = await Promise.all([
      queryOne(ctx.env, 'SELECT id FROM departments WHERE id=? AND active=1', value('department_id')),
      queryOne(ctx.env, 'SELECT id FROM semesters WHERE id=? AND active=1', value('semester_id')),
    ]);
    if (!department) return error('DEPARTMENT_NOT_FOUND', 'القسم الأكاديمي غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);
    if (!semester) return error('SEMESTER_NOT_FOUND', 'الفصل الدراسي غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);
  }

  if (table === 'materials' && value('subject_id')) {
    const row = await queryOne(ctx.env, 'SELECT id FROM subjects WHERE id=? AND active=1', value('subject_id'));
    if (!row) return error('SUBJECT_NOT_FOUND', 'المادة الدراسية غير موجودة أو غير نشطة.', 400, ctx.requestId, ctx.cors);
  }

  if (table === 'schedules') {
    const [department, semester] = await Promise.all([
      queryOne(ctx.env, 'SELECT id FROM departments WHERE id=? AND active=1', value('department_id')),
      queryOne(ctx.env, 'SELECT id FROM semesters WHERE id=? AND active=1', value('semester_id')),
    ]);
    if (!department) return error('DEPARTMENT_NOT_FOUND', 'القسم الأكاديمي غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);
    if (!semester) return error('SEMESTER_NOT_FOUND', 'الفصل الدراسي غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);

    const subjectId = value('subject_id');
    if (!subjectId) return error('SUBJECT_REQUIRED', 'اختر المادة الدراسية للجدول.', 400, ctx.requestId, ctx.cors);
    const subject = await queryOne(ctx.env,
      'SELECT id, department_id, semester_id, active FROM subjects WHERE id=?', subjectId);
    if (!subject || Number(subject.active) !== 1) return error('SUBJECT_NOT_FOUND', 'المادة الدراسية غير موجودة أو غير نشطة.', 400, ctx.requestId, ctx.cors);
    if (subject.department_id !== value('department_id') || subject.semester_id !== value('semester_id')) {
      return error('SCHEDULE_SUBJECT_MISMATCH', 'المادة لا تنتمي إلى القسم والفصل المحددين في الجدول.', 400, ctx.requestId, ctx.cors);
    }
    const day = Number(value('day_of_week'));
    if (!Number.isInteger(day) || day < 0 || day > 6) return error('SCHEDULE_DAY_INVALID', 'يوم الجدول يجب أن يكون رقمًا بين 0 و6.', 400, ctx.requestId, ctx.cors);
    const start = String(value('start_time') || '');
    const end = String(value('end_time') || '');
    if (!/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(end) || start >= end) {
      return error('SCHEDULE_TIME_INVALID', 'وقت بداية المحاضرة يجب أن يسبق وقت نهايتها وبصيغة HH:MM.', 400, ctx.requestId, ctx.cors);
    }
    // A schedule slot may not overlap another active slot in the same
    // department + semester. Adjacent intervals (end == next start) are allowed.
    const conflict = await queryOne(ctx.env, `SELECT id, subject_id, day_of_week, start_time, end_time
      FROM schedules WHERE active=1 AND department_id=? AND semester_id=? AND day_of_week=?
        AND start_time < ? AND end_time > ? AND (? IS NULL OR id<>?) LIMIT 1`,
      value('department_id'), value('semester_id'), day, end, start, existing?.id || null, existing?.id || null);
    if (conflict) {
      const subjectRow = conflict.subject_id ? await queryOne(ctx.env, 'SELECT name_ar FROM subjects WHERE id=?', conflict.subject_id) : null;
      return error('SCHEDULE_TIME_CONFLICT', `تتداخل الحصة مع حصة موجودة${subjectRow?.name_ar ? ` (${subjectRow.name_ar})` : ''} يوم ${day} من ${conflict.start_time} إلى ${conflict.end_time}. غيّر اليوم أو الوقت قبل الحفظ.`, 409, ctx.requestId, ctx.cors);
    }
  }

  return null;
}

export async function writeAudit(ctx, actorId, action, resourceType, resourceId, metadata = {}) {
  await ctx.env.DB.prepare('INSERT INTO audit_logs (id, actor_type, actor_id, action, resource_type, resource_id, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .bind(crypto.randomUUID(), 'staff', actorId, action, resourceType, resourceId, JSON.stringify(metadata || {})).run();
}

export async function adminImportsRoute(ctx, parts, actorId, roleId) {
  if (parts[0] === 'ocr' && ctx.request.method === 'POST') return adminImportOcr(ctx, actorId);
  await ctx.env.DB.prepare("UPDATE import_operations SET status='expired',reviewed_json='[]',summary_json='{}' WHERE status='review' AND expires_at<=?").bind(new Date().toISOString()).run().catch(() => {});
  const id = parts[0] || null;
  const action = parts[1] || null;
  const isSuper = roleId === 'super_admin';
  if (ctx.request.method === 'GET' && !id) {
    if (!isSuper) return error('FORBIDDEN', 'عرض سجل عمليات الاستيراد متاح لمدير النظام فقط.', 403, ctx.requestId, ctx.cors);
    const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
    const rows = await queryAll(ctx.env, `SELECT o.id,o.import_type,o.department_id,o.semester_id,o.status,o.created_by,o.created_at,o.expires_at,o.committed_at,o.rolled_back_at,o.summary_json,d.name_ar AS department_name,s.name_ar AS semester_name,st.display_name AS actor_name
      FROM import_operations o JOIN departments d ON d.id=o.department_id JOIN semesters s ON s.id=o.semester_id LEFT JOIN staff_users st ON st.id=o.created_by ORDER BY o.created_at DESC LIMIT ?`, limit);
    return ok(ctx, rows.map((r) => ({...r, summary: parseJsonValue(r.summary_json, {})})));
  }
  if (ctx.request.method === 'POST' && !id) {
    const body = await parseJson(ctx.request);
    const type = String(body?.type || '');
    const departmentId = String(body?.departmentId || '');
    const semesterId = String(body?.semesterId || '');
    if (!['students','schedule'].includes(type)) return error('IMPORT_TYPE_INVALID','نوع الاستيراد غير مدعوم.',400,ctx.requestId,ctx.cors);
    if (!departmentId || !semesterId) return error('IMPORT_SCOPE_REQUIRED','اختر القسم والفصل الدراسي قبل بدء المسح.',400,ctx.requestId,ctx.cors);
    const [department, semester] = await Promise.all([
      queryOne(ctx.env,'SELECT id FROM departments WHERE id=? AND active=1',departmentId),
      queryOne(ctx.env,'SELECT id FROM semesters WHERE id=? AND active=1',semesterId),
    ]);
    if (!department || !semester) return error('IMPORT_SCOPE_INVALID','القسم أو الفصل الدراسي غير موجود أو غير نشط. اخترهما مجددًا.',400,ctx.requestId,ctx.cors);
    const now = Date.now(); const expiresAt = new Date(now + 60 * 60 * 1000).toISOString();
    const operationId = crypto.randomUUID();
    const initialRows = Array.isArray(body?.records) ? body.records : [];
    if (initialRows.length > 2000) return error('IMPORT_TOO_MANY_ROWS','تحتوي العملية على عدد كبير جدًا من السجلات. قسّم الملف ثم أعد المحاولة.',413,ctx.requestId,ctx.cors);
    await ctx.env.DB.prepare(`INSERT INTO import_operations (id,import_type,department_id,semester_id,status,created_by,expires_at,reviewed_json,summary_json) VALUES (?,?,?,?,'review',?,?,?,?)`)
      .bind(operationId,type,departmentId,semesterId,actorId,expiresAt,JSON.stringify(initialRows),JSON.stringify({detected:initialRows.length})).run();
    await writeAudit(ctx,actorId,'import_started','import_operation',operationId,{type,departmentId,semesterId,rowCount:initialRows.length});
    return ok(ctx,{id:operationId,type,departmentId,semesterId,status:'review',expiresAt,records:initialRows},null,201);
  }
  if (!id) return error('IMPORT_ID_REQUIRED','معرّف عملية الاستيراد مطلوب.',400,ctx.requestId,ctx.cors);
  const operation = await queryOne(ctx.env,'SELECT * FROM import_operations WHERE id=?',id);
  if (!operation) return error('IMPORT_NOT_FOUND','عملية الاستيراد غير موجودة أو انتهت صلاحيتها.',404,ctx.requestId,ctx.cors);
  if (Date.parse(operation.expires_at) <= Date.now() && ['review','expired'].includes(operation.status)) {
    await ctx.env.DB.prepare("UPDATE import_operations SET status='expired', reviewed_json='[]',summary_json='{}' WHERE id=? AND status IN ('review','expired')").bind(id).run();
    return error('IMPORT_EXPIRED','انتهت مهلة عملية الاستيراد (ساعة واحدة). ارجع إلى صفحة الطلاب أو الجداول وابدأ عملية جديدة.',410,ctx.requestId,ctx.cors);
  }
  if (ctx.request.method === 'DELETE' && !action) {
    if (operation.status !== 'review' || (operation.created_by !== actorId && !isSuper)) return error('IMPORT_CANCEL_NOT_ALLOWED','لا يمكن إلغاء هذه العملية من الحساب الحالي أو بعد اعتمادها.',403,ctx.requestId,ctx.cors);
    await writeAudit(ctx,actorId,'import_cancelled','import_operation',id,{type:operation.import_type});
    await ctx.env.DB.prepare('DELETE FROM import_operations WHERE id=? AND status=\'review\'').bind(id).run();
    return ok(ctx,{id,status:'cancelled'});
  }
  if (ctx.request.method === 'PATCH' && action === 'records') {
    if (!isSuper) return error('FORBIDDEN','تعديل نسخة الاستيراد المعتمدة متاح لمدير النظام فقط.',403,ctx.requestId,ctx.cors);
    if (operation.status !== 'committed') return error('IMPORT_NOT_EDITABLE','يمكن تعديل نسخة العملية بعد اعتمادها فقط.',409,ctx.requestId,ctx.cors);
    const body=await parseJson(ctx.request);const rows=Array.isArray(body?.records)?body.records:null;
    if(!rows||rows.length>2000)return error('IMPORT_RECORDS_INVALID','قائمة السجلات المعدلة غير صالحة.',400,ctx.requestId,ctx.cors);
    const items=await queryAll(ctx.env,'SELECT * FROM import_operation_items WHERE operation_id=? ORDER BY rowid',id);
    if(rows.length!==items.length)return error('IMPORT_RECORD_COUNT_MISMATCH','لا يمكن إضافة أو حذف سجلات من مراجعة ما بعد الاعتماد. استخدم التراجع عن العملية إذا أردت إلغاءها بالكامل.',409,ctx.requestId,ctx.cors);
    const statements=[];const updatedRows=[];const pendingSchedules=[];
    for(let i=0;i<items.length;i++){
      const item=items[i], row=rows[i]||{}, after=parseJsonValue(item.after_json,{});
      const table=item.entity_type;const current=await queryOne(ctx.env,`SELECT * FROM ${table} WHERE id=?`,item.entity_id);
      if(!current||['students','schedules'].includes(table)===false)return error('IMPORT_EDIT_CONFLICT','تعذر تعديل العملية لأن أحد السجلات لم يعد موجودًا.',409,ctx.requestId,ctx.cors);
      const keys=table==='students'?['student_number','full_name','email','department_id','current_semester_id','active']:['semester_id','department_id','subject_id','day_of_week','start_time','end_time','room','lecturer','active'];
      if(keys.some((key)=>String(current[key]??'')!==String(after[key]??'')))return error('IMPORT_EDIT_CONFLICT','تغير أحد السجلات بعد الاستيراد. أعد تحميل سجل العملية قبل تعديلها.',409,ctx.requestId,ctx.cors);
      if(table==='students'){
        const number=normalizeStudentNumber(row.studentNumber??row.student_number??'');const name=String(row.fullName??row.full_name??'').trim().replace(/\s+/g,' ');const email=String(row.email??'').trim()||null;
        if(!number||!name||!/^[0-9]+(?:-[0-9]+)?$/.test(number))return error('STUDENT_FIELDS_REQUIRED',`بيانات الطالب رقم ${i+1} غير مكتملة أو غير صالحة.`,400,ctx.requestId,ctx.cors);
        if(email&&!isValidEmail(email))return error('EMAIL_INVALID',`البريد الإلكتروني للطالب رقم ${i+1} غير صالح.`,400,ctx.requestId,ctx.cors);
        const duplicateNumber=await queryOne(ctx.env,'SELECT id FROM students WHERE student_number=? AND id<>?',number,item.entity_id);
        if(duplicateNumber)return error('STUDENT_NUMBER_DUPLICATE',`الرقم الجامعي ${number} مستخدم لدى طالب آخر.`,409,ctx.requestId,ctx.cors);
        if(email){const duplicateEmail=await queryOne(ctx.env,'SELECT id FROM students WHERE lower(email)=lower(?) AND id<>?',email,item.entity_id);if(duplicateEmail)return error('EMAIL_ALREADY_IN_USE','البريد الإلكتروني مستخدم لدى طالب آخر.',409,ctx.requestId,ctx.cors);}
        const scoped=await queryAll(ctx.env,'SELECT id,full_name FROM students WHERE department_id=? AND current_semester_id=? AND id<>?',operation.department_id,operation.semester_id,item.entity_id);
        if(scoped.some((student)=>normalizeStudentName(student.full_name)===normalizeStudentName(name)))return error('STUDENT_NAME_DUPLICATE',`يوجد طالب بالاسم نفسه في القسم والفصل المحددين: ${name}.`,409,ctx.requestId,ctx.cors);
        const next={...after,student_number:number,full_name:name,email};
        statements.push(ctx.env.DB.prepare('UPDATE students SET student_number=?,full_name=?,email=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(number,name,email,item.entity_id));
        statements.push(ctx.env.DB.prepare('UPDATE import_operation_items SET after_json=? WHERE id=?').bind(JSON.stringify(next),item.id));
        updatedRows.push({...row,studentNumber:number,fullName:name,email:email||''});
      }else{
        const subjectId=String(row.subjectId??row.subject_id??'');const day=Number(row.dayOfWeek??row.day_of_week);const start=normalizeTime(row.startTime??row.start_time);const end=normalizeTime(row.endTime??row.end_time);
        if(!subjectId||!Number.isInteger(day)||day<0||day>6||!start||!end||start>=end)return error('SCHEDULE_FIELDS_INVALID',`بيانات الحصة رقم ${i+1} غير مكتملة أو غير صالحة.`,400,ctx.requestId,ctx.cors);
        const subject=await queryOne(ctx.env,'SELECT id,department_id,semester_id,active FROM subjects WHERE id=?',subjectId);
        if(!subject||Number(subject.active)!==1||subject.department_id!==operation.department_id||subject.semester_id!==operation.semester_id)return error('SCHEDULE_SUBJECT_MISMATCH',`المادة في الحصة رقم ${i+1} لا تنتمي إلى النطاق المحدد.`,400,ctx.requestId,ctx.cors);
        const conflict=await queryOne(ctx.env,`SELECT id,start_time,end_time FROM schedules WHERE active=1 AND department_id=? AND semester_id=? AND day_of_week=? AND start_time < ? AND end_time > ? AND id<>? LIMIT 1`,operation.department_id,operation.semester_id,day,end,start,item.entity_id);
        const pending=pendingSchedules.find((slot)=>slot.day===day&&slot.start<end&&slot.end>start);
        if(conflict||pending)return error('SCHEDULE_TIME_CONFLICT',`تتداخل الحصة رقم ${i+1} مع حصة أخرى في اليوم نفسه.`,409,ctx.requestId,ctx.cors);
        pendingSchedules.push({day,start,end});
        const room=String(row.room??'').trim()||null;const lecturer=String(row.lecturer??'').trim()||null;
        const next={...after,subject_id:subjectId,day_of_week:day,start_time:start,end_time:end,room,lecturer};
        statements.push(ctx.env.DB.prepare('UPDATE schedules SET subject_id=?,day_of_week=?,start_time=?,end_time=?,room=?,lecturer=?,updated_at=CURRENT_TIMESTAMP,updated_by=? WHERE id=?').bind(subjectId,day,start,end,room,lecturer,actorId,item.entity_id));
        statements.push(ctx.env.DB.prepare('UPDATE import_operation_items SET after_json=? WHERE id=?').bind(JSON.stringify(next),item.id));
        updatedRows.push({...row,subjectId,dayOfWeek:day,startTime:start,endTime:end,room:room||'',lecturer:lecturer||''});
      }
    }
    statements.push(ctx.env.DB.prepare('UPDATE import_operations SET reviewed_json=?,summary_json=? WHERE id=? AND status=\'committed\'').bind(JSON.stringify(updatedRows),JSON.stringify({editedAt:new Date().toISOString(),editedBy:actorId,reviewed:updatedRows.length}),id));
    statements.push(ctx.env.DB.prepare('INSERT INTO audit_logs (id,actor_type,actor_id,action,resource_type,resource_id,metadata_json) VALUES (?,?,?,?,?,?,?)').bind(crypto.randomUUID(),'staff',actorId,'import_review_updated','import_operation',id,JSON.stringify({recordCount:updatedRows.length})));
    await ctx.env.DB.batch(statements);
    return ok(ctx,{id,status:'committed',updated:updatedRows.length,reviewed:updatedRows});
  }
  if (ctx.request.method === 'GET' && !action) {
    if (!isSuper) return error('FORBIDDEN','مراجعة عمليات الاستيراد السابقة متاحة لمدير النظام فقط.',403,ctx.requestId,ctx.cors);
    const items = await queryAll(ctx.env,'SELECT * FROM import_operation_items WHERE operation_id=? ORDER BY rowid',id);
    return ok(ctx,{...operation,reviewed:parseJsonValue(operation.reviewed_json,[]),summary:parseJsonValue(operation.summary_json,{}),items:items.map((item)=>({...item,before:parseJsonValue(item.before_json,null),after:parseJsonValue(item.after_json,{})}))});
  }
  if (ctx.request.method === 'PATCH' && !action) {
    if (operation.status !== 'review') return error('IMPORT_NOT_REVIEWABLE','لم تعد هذه العملية قابلة للتعديل.',409,ctx.requestId,ctx.cors);
    const body = await parseJson(ctx.request); const rows = body?.records;
    if (!Array.isArray(rows) || rows.length > 2000) return error('IMPORT_RECORDS_INVALID','بيانات المراجعة غير صالحة أو تتجاوز الحد المسموح.',400,ctx.requestId,ctx.cors);
    await ctx.env.DB.prepare('UPDATE import_operations SET reviewed_json=?,summary_json=? WHERE id=? AND status=\'review\'')
      .bind(JSON.stringify(rows),JSON.stringify({reviewed:rows.length}),id).run();
    return ok(ctx,{id,records:rows,expiresAt:operation.expires_at});
  }
  if (ctx.request.method === 'POST' && action === 'validate') {
    if (operation.status !== 'review') return error('IMPORT_NOT_REVIEWABLE','هذه العملية ليست في حالة المراجعة.',409,ctx.requestId,ctx.cors);
    const body = await parseJson(ctx.request); const rows = Array.isArray(body?.records) ? body.records : parseJsonValue(operation.reviewed_json,[]);
    const validation = await validateImportRows(ctx, operation, rows);
    return ok(ctx, {valid: validation.length === 0, errors: validation});
  }
  if (ctx.request.method === 'POST' && action === 'commit') {
    if (operation.status !== 'review') return error('IMPORT_NOT_REVIEWABLE','هذه العملية ليست في حالة المراجعة.',409,ctx.requestId,ctx.cors);
    const body = await parseJson(ctx.request); const rows = Array.isArray(body?.records) ? body.records : parseJsonValue(operation.reviewed_json,[]);
    if (rows.length > 2000) return error('IMPORT_TOO_MANY_ROWS','تجاوزت العملية الحد المسموح من السجلات.',413,ctx.requestId,ctx.cors);
    const statements = []; const items = []; const skipped = []; const errors = [];
    if (operation.import_type === 'students') {
      const seenNumbers = new Set(); const seenNames = new Set();
      const scopedStudents = await queryAll(ctx.env, 'SELECT id,student_number,full_name,department_id,current_semester_id FROM students WHERE department_id=? AND current_semester_id=?', operation.department_id, operation.semester_id);
      const scopedNames = new Map(scopedStudents.map((student) => [normalizeStudentName(student.full_name), student]));
      for (let i=0;i<rows.length;i++) {
        const row=rows[i]||{}; if (row._remove === true) { skipped.push({index:i,reason:'removed'}); continue; }
        const number=normalizeStudentNumber(row.studentNumber ?? row.student_number ?? row.number ?? '');
        const name=String(row.fullName ?? row.full_name ?? row.name ?? '').trim().replace(/\s+/g,' ');
        if (!number || !name) { errors.push({index:i,code:'STUDENT_FIELDS_REQUIRED',message:'الاسم والرقم الجامعي مطلوبان.'}); continue; }
        if (!/^[0-9]+(?:-[0-9]+)?$/.test(number)) { errors.push({index:i,code:'STUDENT_NUMBER_INVALID',message:'صيغة الرقم الجامعي غير صالحة.'}); continue; }
        const normalizedName = normalizeStudentName(name);
        const byNumber=seenNumbers.has(number) ? {student_number:number,full_name:name} : await queryOne(ctx.env,'SELECT id,student_number,full_name,department_id,current_semester_id FROM students WHERE student_number=?',number);
        if (byNumber) { errors.push({index:i,code:'STUDENT_NUMBER_DUPLICATE',message:`الرقم الجامعي ${number} موجود مسبقًا أو مكرر داخل الملف؛ لن يتم تحديث الطالب عبر الاستيراد.`,existing:byNumber}); continue; }
        const byName=scopedNames.get(normalizedName) || (seenNames.has(normalizedName) ? {student_number:'ضمن الملف'} : null);
        if (byName) { errors.push({index:i,code:'STUDENT_NAME_DUPLICATE',message:`يوجد طالب بالاسم نفسه في القسم والفصل المحددين (${byName.student_number || 'سجل آخر في الملف'}).`,existing:byName}); continue; }
        const email=String(row.email||'').trim()||null; if(email&&!isValidEmail(email)){errors.push({index:i,code:'EMAIL_INVALID',message:'صيغة البريد الإلكتروني غير صالحة.'});continue;}
        const entityId=crypto.randomUUID();
        seenNumbers.add(number); seenNames.add(normalizedName);
        statements.push(ctx.env.DB.prepare(`INSERT INTO students (id,student_number,full_name,email,department_id,current_semester_id,active) VALUES (?,?,?,?,?,?,1)`).bind(entityId,number,name,email,operation.department_id,operation.semester_id));
        items.push({id:crypto.randomUUID(),entity_type:'students',entity_id:entityId,action:'insert',before_json:null,after_json:JSON.stringify({id:entityId,student_number:number,full_name:name,email,department_id:operation.department_id,current_semester_id:operation.semester_id,active:1})});
      }
    } else {
      const pendingSchedules = [];
      for (let i=0;i<rows.length;i++) {
        const row=rows[i]||{}; if(row._remove===true){skipped.push({index:i,reason:'removed'});continue;}
        const subjectId=String(row.subjectId??row.subject_id??''); const day=Number(row.dayOfWeek??row.day_of_week); const start=normalizeTime(row.startTime??row.start_time); const end=normalizeTime(row.endTime??row.end_time);
        if(!subjectId||!Number.isInteger(day)||day<0||day>6||!start||!end||start>=end){errors.push({index:i,code:'SCHEDULE_FIELDS_INVALID',message:'المادة واليوم ووقت البداية والنهاية مطلوبة وصحيحة.'});continue;}
        const subject=await queryOne(ctx.env,'SELECT id,department_id,semester_id,active,name_ar FROM subjects WHERE id=?',subjectId);
        if(!subject||Number(subject.active)!==1||subject.department_id!==operation.department_id||subject.semester_id!==operation.semester_id){errors.push({index:i,code:'SCHEDULE_SUBJECT_MISMATCH',message:'المادة لا تنتمي إلى القسم والفصل المحددين.'});continue;}
        const existingId=String(row.existingId??row.existing_id??''); const existing=existingId?await queryOne(ctx.env,'SELECT * FROM schedules WHERE id=? AND active=1',existingId):null;
        if(existingId&&!existing){errors.push({index:i,code:'SCHEDULE_TARGET_NOT_FOUND',message:'الحصة المطلوب تحديثها لم تعد موجودة. حدّث المراجعة قبل المتابعة.'});continue;}
        if(existing&&(existing.department_id!==operation.department_id||existing.semester_id!==operation.semester_id)){errors.push({index:i,code:'SCHEDULE_TARGET_SCOPE_MISMATCH',message:'الحصة المختارة للتحديث خارج القسم والفصل المحددين.'});continue;}
        const conflict=await queryOne(ctx.env,`SELECT sch.id,sch.start_time,sch.end_time,sub.name_ar AS subject_name FROM schedules sch LEFT JOIN subjects sub ON sub.id=sch.subject_id WHERE sch.active=1 AND sch.department_id=? AND sch.semester_id=? AND sch.day_of_week=? AND sch.start_time < ? AND sch.end_time > ? AND (?='' OR sch.id<>?) LIMIT 1`,operation.department_id,operation.semester_id,day,end,start,existingId,existingId);
        const pendingConflict=pendingSchedules.find((slot)=>slot.day===day && slot.start<end && slot.end>start);
        if(conflict || pendingConflict){const match=conflict||pendingConflict;errors.push({index:i,code:'SCHEDULE_TIME_CONFLICT',message:`تعارض زمني مع ${match.subject_name||'حصة أخرى في الملف'} (${match.start_time||match.start}–${match.end_time||match.end}).`,existing:match});continue;}
        pendingSchedules.push({day,start,end,subject_name:subject.name_ar});
        const newId=crypto.randomUUID(); const after={id:newId,semester_id:operation.semester_id,department_id:operation.department_id,subject_id:subjectId,day_of_week:day,start_time:start,end_time:end,room:String(row.room||'').trim()||null,lecturer:String(row.lecturer||'').trim()||null,active:1};
        if(existing){statements.push(ctx.env.DB.prepare('DELETE FROM schedules WHERE id=?').bind(existing.id));}
        statements.push(ctx.env.DB.prepare(`INSERT INTO schedules (id,semester_id,department_id,subject_id,day_of_week,start_time,end_time,room,lecturer,active,created_by,updated_by) VALUES (?,?,?,?,?,?,?,?,?,1,?,?)`).bind(newId,operation.semester_id,operation.department_id,subjectId,day,start,end,after.room,after.lecturer,actorId,actorId));
        items.push({id:crypto.randomUUID(),entity_type:'schedules',entity_id:newId,action:existing?'replace':'insert',before_json:existing?JSON.stringify(existing):null,after_json:JSON.stringify(after)});
      }
    }
    if(errors.length) return error('IMPORT_VALIDATION_FAILED','توجد سجلات تحتاج إلى مراجعة. لم يتم حفظ أي سجل؛ صحح الأخطاء أو استبعد السجلات المشار إليها ثم أعد الاعتماد.',409,ctx.requestId,ctx.cors,JSON.stringify(errors.slice(0,30)));
    if(!statements.length) return error('IMPORT_EMPTY','لا توجد سجلات صالحة للحفظ بعد المراجعة.',400,ctx.requestId,ctx.cors);
    const now=new Date().toISOString();
    statements.push(ctx.env.DB.prepare(`UPDATE import_operations SET status='committed',committed_at=?,reviewed_json=?,summary_json=? WHERE id=? AND status='review'`).bind(now,JSON.stringify(rows),JSON.stringify({saved:items.length,skipped:skipped.length}),id));
    for(const item of items){statements.push(ctx.env.DB.prepare('INSERT INTO import_operation_items (id,operation_id,entity_type,entity_id,action,before_json,after_json) VALUES (?,?,?,?,?,?,?)').bind(item.id,id,item.entity_type,item.entity_id,item.action,item.before_json,item.after_json));}
    statements.push(ctx.env.DB.prepare('INSERT INTO audit_logs (id,actor_type,actor_id,action,resource_type,resource_id,metadata_json) VALUES (?,?,?,?,?,?,?)').bind(crypto.randomUUID(),'staff',actorId,'import_committed','import_operation',id,JSON.stringify({type:operation.import_type,saved:items.length,skipped:skipped.length})));
    await ctx.env.DB.batch(statements);
    return ok(ctx,{id,status:'committed',saved:items.length,skipped:skipped.length,expiresAt:operation.expires_at});
  }
  if (ctx.request.method === 'POST' && action === 'rollback') {
    if(!isSuper) return error('FORBIDDEN','التراجع عن الاستيراد متاح لمدير النظام فقط.',403,ctx.requestId,ctx.cors);
    if(operation.status!=='committed') return error('IMPORT_NOT_ROLLBACKABLE','يمكن التراجع فقط عن عملية مكتملة لم يسبق التراجع عنها.',409,ctx.requestId,ctx.cors);
    const items=await queryAll(ctx.env,'SELECT * FROM import_operation_items WHERE operation_id=? ORDER BY rowid DESC',id); const statements=[]; const blocked=[];
    for(const item of items){
      const after=parseJsonValue(item.after_json,{}); const current=await queryOne(ctx.env,`SELECT * FROM ${item.entity_type} WHERE id=?`,item.entity_id);
      if(!current){blocked.push({id:item.entity_id,reason:'missing'});continue;}
      const expectedKeys=item.entity_type==='students'?['student_number','full_name','email','department_id','current_semester_id','active']:['semester_id','department_id','subject_id','day_of_week','start_time','end_time','room','lecturer','active'];
      const changed=expectedKeys.some((key)=>String(current[key]??'')!==String(after[key]??''));
      if(changed){blocked.push({id:item.entity_id,reason:'modified_after_import'});continue;}
      if(item.entity_type==='students' && item.action==='insert') {
        const dependentTables=['sessions','material_progress','xp_events','student_stats','student_badges','comments','reactions','notification_devices','material_progress_events','learning_events','learning_event_completions','eino_conversations','public_chat_messages','public_chat_reports','password_reset_codes'];
        let hasDependents=false;
        for(const tableName of dependentTables){
          const found=await queryOne(ctx.env,`SELECT 1 AS present FROM ${tableName} WHERE student_id=? LIMIT 1`,item.entity_id).catch(()=>null);
          if(found){hasDependents=true;break;}
        }
        if(hasDependents){blocked.push({id:item.entity_id,reason:'student_has_related_data'});continue;}
      }
      if(item.action==='insert') statements.push(ctx.env.DB.prepare(`DELETE FROM ${item.entity_type} WHERE id=?`).bind(item.entity_id));
      else if(item.action==='replace'&&item.before_json){
        const before=parseJsonValue(item.before_json,{});
        statements.push(ctx.env.DB.prepare('DELETE FROM schedules WHERE id=?').bind(item.entity_id));
        const cols=['id','semester_id','department_id','subject_id','day_of_week','start_time','end_time','room','lecturer','active'];
        statements.push(ctx.env.DB.prepare(`INSERT INTO schedules (${cols.join(',')}) VALUES (${cols.map(()=>'?').join(',')})`).bind(...cols.map((c)=>before[c]??null)));
      }
      statements.push(ctx.env.DB.prepare('UPDATE import_operation_items SET rolled_back=1 WHERE id=?').bind(item.id));
    }
    if(blocked.length) return error('IMPORT_ROLLBACK_BLOCKED','تعذر التراجع الكامل لأن بعض السجلات تغيرت أو ارتبطت ببيانات أخرى. لم يتم تنفيذ التراجع؛ راجع تفاصيل السجلات المتأثرة.',409,ctx.requestId,ctx.cors,JSON.stringify(blocked.slice(0,30)));
    statements.push(ctx.env.DB.prepare("UPDATE import_operations SET status='rolled_back',rolled_back_at=? WHERE id=? AND status='committed'").bind(new Date().toISOString(),id));
    statements.push(ctx.env.DB.prepare('INSERT INTO audit_logs (id,actor_type,actor_id,action,resource_type,resource_id,metadata_json) VALUES (?,?,?,?,?,?,?)').bind(crypto.randomUUID(),'staff',actorId,'import_rolled_back','import_operation',id,JSON.stringify({items:items.length})));
    await ctx.env.DB.batch(statements);
    return ok(ctx,{id,status:'rolled_back',rolledBack:items.length});
  }
  return error('IMPORT_ACTION_NOT_FOUND','الإجراء المطلوب لعملية الاستيراد غير معروف.',404,ctx.requestId,ctx.cors);
}

async function validateImportRows(ctx, operation, rows) {
  const errors=[];
  if(!Array.isArray(rows)||rows.length>2000) return [{index:-1,code:'IMPORT_RECORDS_INVALID',message:'قائمة السجلات غير صالحة أو تتجاوز الحد المسموح.'}];
  if(operation.import_type==='students'){
    const numbers=new Set(), names=new Set();
    const [allNumbers, scoped] = await Promise.all([
      queryAll(ctx.env,'SELECT student_number FROM students'),
      queryAll(ctx.env,'SELECT student_number,full_name FROM students WHERE department_id=? AND current_semester_id=?',operation.department_id,operation.semester_id),
    ]);
    const existingNumbers=new Set(allNumbers.map((r)=>normalizeStudentNumber(r.student_number)));
    const existingNames=new Map(scoped.map((r)=>[normalizeStudentName(r.full_name),r.student_number]));
    rows.forEach((row,index)=>{
      if(row?._remove===true)return;
      const number=normalizeStudentNumber(row?.studentNumber??row?.student_number??row?.number??'');
      const name=String(row?.fullName??row?.full_name??row?.name??'').trim().replace(/\s+/g,' ');
      if(!number||!name){errors.push({index,code:'STUDENT_FIELDS_REQUIRED',message:'الاسم والرقم الجامعي مطلوبان.'});return;}
      if(!/^[0-9]+(?:-[0-9]+)?$/.test(number)){errors.push({index,code:'STUDENT_NUMBER_INVALID',message:'صيغة الرقم الجامعي غير صالحة.'});return;}
      if(existingNumbers.has(number)||numbers.has(number)){errors.push({index,code:'STUDENT_NUMBER_DUPLICATE',message:`الرقم الجامعي ${number} موجود مسبقًا أو مكرر داخل الملف.`});return;}
      const normalizedName=normalizeStudentName(name);
      if(existingNames.has(normalizedName)||names.has(normalizedName)){errors.push({index,code:'STUDENT_NAME_DUPLICATE',message:`يوجد اسم مطابق في القسم والفصل المحددين (${existingNames.get(normalizedName)||'ضمن الملف'}).`});return;}
      const email=String(row?.email||'').trim(); if(email&&!isValidEmail(email)){errors.push({index,code:'EMAIL_INVALID',message:'صيغة البريد الإلكتروني غير صالحة.'});return;}
      numbers.add(number);names.add(normalizedName);
    });
  } else {
    const pending=[];
    for(let index=0;index<rows.length;index++){
      const row=rows[index]||{}; if(row._remove===true)continue;
      const subjectId=String(row.subjectId??row.subject_id??'');const day=Number(row.dayOfWeek??row.day_of_week);const start=normalizeTime(row.startTime??row.start_time);const end=normalizeTime(row.endTime??row.end_time);
      if(!subjectId||!Number.isInteger(day)||day<0||day>6||!start||!end||start>=end){errors.push({index,code:'SCHEDULE_FIELDS_INVALID',message:'المادة واليوم ووقت البداية والنهاية مطلوبة وصحيحة.'});continue;}
      const subject=await queryOne(ctx.env,'SELECT id,department_id,semester_id,active,name_ar FROM subjects WHERE id=?',subjectId);
      if(!subject||Number(subject.active)!==1||subject.department_id!==operation.department_id||subject.semester_id!==operation.semester_id){errors.push({index,code:'SCHEDULE_SUBJECT_MISMATCH',message:'المادة لا تنتمي إلى القسم والفصل المحددين.'});continue;}
      const existingId=String(row.existingId??row.existing_id??'');const existing=existingId?await queryOne(ctx.env,'SELECT id,department_id,semester_id FROM schedules WHERE id=? AND active=1',existingId):null;
      if(existingId&&(!existing||existing.department_id!==operation.department_id||existing.semester_id!==operation.semester_id)){errors.push({index,code:'SCHEDULE_TARGET_NOT_FOUND',message:'الحصة المختارة للتحديث لم تعد موجودة ضمن النطاق المحدد.'});continue;}
      const conflict=await queryOne(ctx.env,`SELECT sch.id,sch.start_time,sch.end_time,sub.name_ar AS subject_name FROM schedules sch LEFT JOIN subjects sub ON sub.id=sch.subject_id WHERE sch.active=1 AND sch.department_id=? AND sch.semester_id=? AND sch.day_of_week=? AND sch.start_time < ? AND sch.end_time > ? AND (?='' OR sch.id<>?) LIMIT 1`,operation.department_id,operation.semester_id,day,end,start,existingId,existingId);
      const pendingConflict=pending.find((slot)=>slot.day===day&&slot.start<end&&slot.end>start);
      if(conflict||pendingConflict){const match=conflict||pendingConflict;errors.push({index,code:'SCHEDULE_TIME_CONFLICT',message:`تعارض زمني مع ${match.subject_name||'حصة أخرى في الملف'} (${match.start_time||match.start}–${match.end_time||match.end}).`});continue;}
      pending.push({day,start,end,subject_name:subject.name_ar});
    }
  }
  return errors;
}

async function adminImportOcr(ctx, actorId) {
  const form = await ctx.request.formData().catch(() => null);
  const file = form?.get('file');
  if (!(file instanceof File) || !file.size) return error('IMPORT_FILE_REQUIRED','اختر ملفًا أو صورة للمسح أولًا.',400,ctx.requestId,ctx.cors);
  if (file.size > 100 * 1024 * 1024) return error('IMPORT_FILE_TOO_LARGE','حجم الملف يتجاوز 100 ميغابايت. اختر ملفًا أصغر ثم أعد المحاولة.',413,ctx.requestId,ctx.cors);
  const type = String(file.type || '').toLowerCase();
  const name = String(file.name || '').toLowerCase();
  const isImage = ['image/jpeg','image/png','image/webp','image/tiff'].includes(type);
  const isPdf = type === 'application/pdf' || name.endsWith('.pdf');
  if (!isImage && !isPdf) return error('IMPORT_FILE_TYPE_UNSUPPORTED','هذا المسار مخصص للصور وملفات PDF فقط. استخدم CSV أو Excel لملفات الجداول.',415,ctx.requestId,ctx.cors);
  if (!ctx.env.OCR_SPACE_API_KEY) return error('IMPORT_OCR_NOT_CONFIGURED','خدمة OCR.space غير مهيأة على الخادم. أضف OCR_SPACE_API_KEY إلى أسرار Cloudflare Worker ثم أعد المحاولة.',503,ctx.requestId,ctx.cors);
  // The client compresses/rasterizes files before upload. Enforce the free-tier
  // provider limit again here; never spend quota on a file that cannot be accepted.
  const providerMaxBytes = 1024 * 1024;
  if (file.size > providerMaxBytes) return error('IMPORT_FILE_OVER_PROVIDER_LIMIT','حجم الملف بعد الضغط ما زال أكبر من 1 ميغابايت. قلّل دقة المسح أو أرسل صورة أوضح وأصغر.',413,ctx.requestId,ctx.cors);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 90000);
  try {
    const result = await ocrSpaceFromFile({apiKey:ctx.env.OCR_SPACE_API_KEY,file,signal:controller.signal});
    const pages = Number.isInteger(result?.pageCount) ? result.pageCount : 1;
    if (pages > 1) return error('IMPORT_MULTIPAGE_FILE','يحتوي المستند على أكثر من صفحة. أدرج صفحة واحدة فقط ثم أعد المسح؛ يمكن أن تحتوي الصفحة الواحدة على أسطر كثيرة.',400,ctx.requestId,ctx.cors);
    const text = String(result?.text || '').trim();
    if (!text) return error('IMPORT_OCR_EMPTY','لم يتمكن محرك OCR من قراءة نص واضح. حسّن وضوح الصورة أو جرّب قالبًا مدعومًا آخر.',422,ctx.requestId,ctx.cors);
    await writeAudit(ctx,actorId,'import_ocr_completed','import_source',null,{filename:String(file.name||'').slice(0,120),sizeBytes:file.size,contentType:type,provider:'ocr.space',pageCount:pages});
    return ok(ctx,{text,pageCount:pages,provider:'ocr.space',uploadedBytes:file.size});
  } catch (e) {
    const status = Number(e?.status || 0);
    console.warn('Admin import OCR failed',String(e?.message||e).slice(0,180));
    if (status === 429) return error('IMPORT_OCR_QUOTA_EXCEEDED','وصلت خدمة OCR إلى حد الاستخدام الحالي أو تجاوزت المعدل المسموح. لم يتم الحفظ؛ جرّب لاحقًا أو أكمل الإدخال يدويًا.',429,ctx.requestId,ctx.cors);
    return error('IMPORT_OCR_FAILED','تعذر استخراج النص من خدمة OCR. تحقق من المفتاح وحجم الملف ووضوحه ثم أعد المحاولة أو أدخل البيانات يدويًا.',502,ctx.requestId,ctx.cors);
  } finally { clearTimeout(timeout); }
}

function normalizeStudentNumber(value) {
  return normalizeDigits(String(value ?? '')).replace(/\s+/g,'').trim();
}
function normalizeStudentName(value) {
  return String(value ?? '').normalize('NFC').trim().replace(/\s+/g,' ').replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي');
}
function normalizeDigits(value) {
  const arabic='٠١٢٣٤٥٦٧٨٩'; const persian='۰۱۲۳۴۵۶۷۸۹';
  return String(value).replace(/[٠-٩]/g,(c)=>String(arabic.indexOf(c))).replace(/[۰-۹]/g,(c)=>String(persian.indexOf(c)));
}
function normalizeTime(value) {
  const raw=normalizeDigits(String(value??'')).trim();
  const match=raw.match(/^(\d{1,2})(?::(\d{1,2}))?$/); if(!match)return null;
  const hour=Number(match[1]); const minute=Number(match[2]??0);
  if(hour<0||hour>23||minute<0||minute>59)return null;
  return `${String(hour).padStart(2,'0')}:${String(minute).padStart(2,'0')}`;
}

export async function adminCrud(ctx, table, id, actorId) {
  if (ctx.request.method === 'GET') {
    const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
    const offset = Math.max(0, Number.parseInt(ctx.url.searchParams.get('offset') || '0', 10) || 0);
    const columns = ADMIN_SELECT_COLUMNS[table];
    if (!columns) return error('ADMIN_RESOURCE_NOT_FOUND','وحدة الإدارة غير معروفة.',404,ctx.requestId,ctx.cors);
    let where = '';
    const params = [];
    if (table === 'students') {
      const q = String(ctx.url.searchParams.get('q') || '').trim();
      const department = String(ctx.url.searchParams.get('department') || '').trim();
      const semester = String(ctx.url.searchParams.get('semester') || '').trim();
      const clauses = [];
      if (q) { clauses.push('(student_number LIKE ? OR full_name LIKE ? OR email LIKE ?)'); const like = `%${q}%`; params.push(like, like, like); }
      if (department) { clauses.push('department_id = ?'); params.push(department); }
      if (semester) { clauses.push('current_semester_id = ?'); params.push(semester); }
      if (clauses.length) where = ` WHERE ${clauses.join(' AND ')}`;
    }
    const rows = await queryAll(ctx.env, `SELECT ${columns} FROM ${table}${where} ORDER BY rowid DESC LIMIT ? OFFSET ?`, ...params, limit, offset);
    const count = await queryOne(ctx.env, `SELECT COUNT(*) AS count FROM ${table}${where}`, ...params);
    return ok(ctx, rows, { limit, offset, total: Number(count?.count || 0) });
  }
  if (ctx.request.method === 'POST') {
    const body = await parseJson(ctx.request); const fields = cleanAdminPayload(table, body);
    // Events are always immediately available; their label is derived from dates, never a draft/publish state.
    if (table === 'events') fields.status = 'published';
    if (CONTENT_TABLES.has(table) && fields.status !== undefined && !CONTENT_STATUS_VALUES.has(String(fields.status))) return error('CONTENT_STATUS_INVALID','حالة المحتوى غير مدعومة.',400,ctx.requestId,ctx.cors);
    const id = String(body?.id || makeId(table.slice(0, -1) || table));
    if (table === 'students') {
      if (!fields.student_number || !fields.full_name || !fields.department_id) {
        return error('STUDENT_INPUT_INVALID','بيانات الطالب الأساسية مطلوبة.',400,ctx.requestId,ctx.cors);
      }
      if (!/^[0-9]+(?:-[0-9]+)?$/.test(String(fields.student_number).trim())) {
        return error('STUDENT_NUMBER_INVALID','صيغة الرقم الجامعي غير صالحة. استخدم أرقامًا فقط أو أرقامًا مفصولة بشرطة (-).',400,ctx.requestId,ctx.cors);
      }
      if (fields.email != null && fields.email !== '' && !isValidEmail(fields.email)) {
        return error('EMAIL_INVALID','يرجى إدخال بريد إلكتروني صالح.',400,ctx.requestId,ctx.cors);
      }
      if (fields.email) {
        const emailInUse = await queryOne(ctx.env, 'SELECT id FROM students WHERE lower(email)=?', fields.email);
        if (emailInUse) return error('EMAIL_ALREADY_IN_USE','البريد الإلكتروني مستخدم بالفعل لحساب طالب آخر.',409,ctx.requestId,ctx.cors);
      }
    }
    if (table === 'subjects' && (!fields.semester_id || !fields.department_id || !fields.name_ar)) return error('SUBJECT_INPUT_INVALID','بيانات المادة الأساسية مطلوبة.',400,ctx.requestId,ctx.cors);
    if (table === 'materials' && (!fields.subject_id || !fields.title)) return error('MATERIAL_INPUT_INVALID','المادة والعنوان مطلوبان.',400,ctx.requestId,ctx.cors);
    if (table === 'schedules' && (!fields.semester_id || !fields.department_id || fields.day_of_week == null || !fields.start_time || !fields.end_time)) return error('SCHEDULE_INPUT_INVALID','بيانات الجدول الأساسية مطلوبة.',400,ctx.requestId,ctx.cors);
    const academicError = await validateAcademicReferences(ctx, table, fields);
    if (academicError) return academicError;
    const cols = ['id', ...Object.keys(fields)]; const vals = [id, ...Object.values(fields)];
    if (table === 'news' || table === 'events' || table === 'announcements' || table === 'achievements') { cols.push('created_by'); vals.push(actorId); }
    if (table === 'schedules') { cols.push('created_by','updated_by'); vals.push(actorId,actorId); }
    const marks = cols.map(()=>'?').join(',');
    await ctx.env.DB.prepare(`INSERT INTO ${table} (${cols.join(',')}) VALUES (${marks})`).bind(...vals.map(sqlValue)).run();
    if (CONTENT_TABLES.has(table)) await markOwnedMediaAttached(ctx, extractMediaUrlsFromRow(ctx, fields));
    await writeAudit(ctx, actorId, 'create', table, id, { fields: Object.keys(fields) });
    const createdRow = await queryOne(ctx.env, `SELECT * FROM ${table} WHERE id=?`, id);
    const notificationDraftId = await createOrRefreshContentNotificationDraft(ctx, table, createdRow, actorId);
    return ok(ctx, { ...createdRow, notification_draft_id: notificationDraftId }, null, 201);
  }
  if (!id) return error('ADMIN_ID_REQUIRED','معرّف السجل مطلوب.',400,ctx.requestId,ctx.cors);
  if (ctx.request.method === 'PATCH') {
    const body = await parseJson(ctx.request); const fields = cleanAdminPayload(table, body);
    // Ignore legacy status payloads for events: the event lifecycle is date-based only.
    if (table === 'events') delete fields.status;
    if (CONTENT_TABLES.has(table) && fields.status !== undefined && !CONTENT_STATUS_VALUES.has(String(fields.status))) return error('CONTENT_STATUS_INVALID','حالة المحتوى غير مدعومة.',400,ctx.requestId,ctx.cors);
    if (!Object.keys(fields).length) return error('ADMIN_NO_FIELDS','لم يتم إرسال أي تغييرات.',400,ctx.requestId,ctx.cors);
    if (table === 'students' && fields.student_number !== undefined &&
        !/^[0-9]+(?:-[0-9]+)?$/.test(String(fields.student_number).trim())) {
      return error('STUDENT_NUMBER_INVALID','صيغة الرقم الجامعي غير صالحة. استخدم أرقامًا فقط أو أرقامًا مفصولة بشرطة (-).',400,ctx.requestId,ctx.cors);
    }
    if (table === 'students' && fields.email !== undefined && fields.email !== null && fields.email !== '' && !isValidEmail(fields.email)) {
      return error('EMAIL_INVALID','يرجى إدخال بريد إلكتروني صالح.',400,ctx.requestId,ctx.cors);
    }
    if (table === 'students' && fields.email) {
      const emailInUse = await queryOne(ctx.env, 'SELECT id FROM students WHERE lower(email)=? AND id<>?', fields.email, id);
      if (emailInUse) return error('EMAIL_ALREADY_IN_USE','البريد الإلكتروني مستخدم بالفعل لحساب طالب آخر.',409,ctx.requestId,ctx.cors);
    }
    const existing = await queryOne(ctx.env, `SELECT * FROM ${table} WHERE id=?`, id);
    if (!existing) return error('ADMIN_NOT_FOUND','السجل غير موجود.',404,ctx.requestId,ctx.cors);
    const oldMediaUrls = CONTENT_TABLES.has(table) ? extractMediaUrlsFromRow(ctx, existing) : [];
    const notificationRelevantFields = {
      schedules: ['semester_id','department_id','subject_id','day_of_week','start_time','end_time','room','lecturer'],
      materials: ['subject_id','title','description','drive_file_id','drive_url','mime_type','size_bytes'],
      achievements: ['title','description','intro','highlights','highlights_title','badge','publisher','achieved_at','images_json','image_url'],
    }[table] || [];
    const shouldCreateNotificationDraft = notificationRelevantFields.some(key => Object.prototype.hasOwnProperty.call(fields, key) && String(fields[key] ?? '') !== String(existing[key] ?? ''));
    const academicError = await validateAcademicReferences(ctx, table, fields, existing);
    if (academicError) return academicError;
    if (CONTENT_UPDATED_BY_TABLES.has(table)) { fields.updated_by = actorId; fields.updated_at = new Date().toISOString(); }
    if (table === 'announcements') { fields.updated_at = new Date().toISOString(); }
    if (table === 'achievements') { fields.updated_at = new Date().toISOString(); fields.updated_by = actorId; }
    if (table === 'schedules') { fields.updated_at = new Date().toISOString(); fields.updated_by = actorId; }
    const sets = Object.keys(fields).map(k=>`${k}=?`).join(',');
    const result = await ctx.env.DB.prepare(`UPDATE ${table} SET ${sets} WHERE id=?`).bind(...Object.values(fields).map(sqlValue), id).run();
    if (!result.meta?.changes) return error('ADMIN_NOT_FOUND','السجل غير موجود.',404,ctx.requestId,ctx.cors);
    const updatedRow = await queryOne(ctx.env, `SELECT * FROM ${table} WHERE id=?`, id);
    if (CONTENT_TABLES.has(table)) {
      const newMediaUrls = extractMediaUrlsFromRow(ctx, updatedRow);
      await markOwnedMediaAttached(ctx, newMediaUrls);
      const removed = oldMediaUrls.filter(u => !newMediaUrls.includes(u));
      if (removed.length) await deleteOwnedMediaUrls(ctx, removed);
    }
    await writeAudit(ctx, actorId, 'update', table, id, { fields: Object.keys(fields) });
    const notificationDraftId = shouldCreateNotificationDraft ? await createOrRefreshContentNotificationDraft(ctx, table, updatedRow, actorId) : null;
    return ok(ctx, { ...updatedRow, notification_draft_id: notificationDraftId });
  }
  if (ctx.request.method === 'DELETE') {
    const existing = await queryOne(ctx.env, `SELECT * FROM ${table} WHERE id=?`, id);
    if (!existing) return error('ADMIN_NOT_FOUND','السجل غير موجود.',404,ctx.requestId,ctx.cors);

    const deleteGenericContentRefs = async (contentType, contentId) => {
      const comments = await queryAll(ctx.env, 'SELECT id FROM comments WHERE content_type=? AND content_id=?', contentType, contentId);
      const commentIds = comments.map(r => r.id);
      const stmts = [];
      if (commentIds.length) {
        const marks = commentIds.map(() => '?').join(',');
        stmts.push(ctx.env.DB.prepare(`DELETE FROM comment_reactions WHERE comment_id IN (${marks})`).bind(...commentIds));
        stmts.push(ctx.env.DB.prepare(`DELETE FROM comment_replies WHERE comment_id IN (${marks})`).bind(...commentIds));
        stmts.push(ctx.env.DB.prepare(`DELETE FROM comments WHERE id IN (${marks})`).bind(...commentIds));
      }
      stmts.push(ctx.env.DB.prepare('DELETE FROM reactions WHERE content_type=? AND content_id=?').bind(contentType, contentId));
      if (stmts.length) await ctx.env.DB.batch(stmts);
    };

    if (table === 'staff_users') {
      if (id === actorId) return error('STAFF_SELF_DELETE_FORBIDDEN','لا يمكنك حذف حسابك الحالي.',400,ctx.requestId,ctx.cors);
      const staffDeleteBatch = await ctx.env.DB.batch([
        ctx.env.DB.prepare('DELETE FROM sessions WHERE staff_user_id=?').bind(id),
        ctx.env.DB.prepare('UPDATE news SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
        ctx.env.DB.prepare('UPDATE events SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
        ctx.env.DB.prepare('UPDATE achievements SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
        ctx.env.DB.prepare('UPDATE announcements SET created_by=NULL WHERE created_by=?').bind(id),
        ctx.env.DB.prepare('UPDATE schedules SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
        ctx.env.DB.prepare('UPDATE app_settings SET updated_by=NULL WHERE updated_by=?').bind(id),
        ctx.env.DB.prepare('DELETE FROM staff_users WHERE id=?').bind(id),
      ]);
      const result = staffDeleteBatch[staffDeleteBatch.length - 1];
      if (!result.meta?.changes) return error('ADMIN_NOT_FOUND','المستخدم غير موجود.',404,ctx.requestId,ctx.cors);
      await writeAudit(ctx, actorId, 'delete', 'staff_users', id, { mode: 'hard_delete' });
      return ok(ctx, { deleted:true, id, mode:'hard_delete' });
    }

    if (table === 'students') {
      const commentRows = await queryAll(ctx.env, 'SELECT id FROM comments WHERE student_id=?', id);
      const commentIds = commentRows.map(r => r.id);
      const stmts = [];
      if (commentIds.length) {
        const marks = commentIds.map(() => '?').join(',');
        stmts.push(ctx.env.DB.prepare(`DELETE FROM comment_reactions WHERE comment_id IN (${marks})`).bind(...commentIds));
        stmts.push(ctx.env.DB.prepare(`DELETE FROM comment_replies WHERE comment_id IN (${marks})`).bind(...commentIds));
        stmts.push(ctx.env.DB.prepare(`DELETE FROM comments WHERE id IN (${marks})`).bind(...commentIds));
      }
      stmts.push(ctx.env.DB.prepare('DELETE FROM notification_dispatch_queue WHERE notification_target_id IN (SELECT id FROM notification_targets WHERE student_id=?)').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM notification_targets WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM notification_devices WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM material_progress_events WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM material_progress WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM student_badges WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM xp_events WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM student_stats WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM interaction_rate_limits WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM sessions WHERE student_id=?').bind(id));
      // A student can author replies under another student's comment, so
      // deleting only replies belonging to the student's own comments is insufficient.
      stmts.push(ctx.env.DB.prepare('DELETE FROM comment_replies WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM comment_reactions WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM eino_memories WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM reactions WHERE student_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM students WHERE id=?').bind(id));
      const studentDeleteBatch = await ctx.env.DB.batch(stmts);
      const result = studentDeleteBatch[studentDeleteBatch.length - 1];
      if (!result.meta?.changes) return error('ADMIN_NOT_FOUND','الطالب غير موجود.',404,ctx.requestId,ctx.cors);
      await writeAudit(ctx, actorId, 'delete', 'students', id, { mode:'hard_delete', xp_policy:'preserved_history_is_not_applicable_after_student_delete' });
      return ok(ctx, { deleted:true, id, mode:'hard_delete' });
    }

    if (table === 'materials') {
      const fileId = String(existing.drive_file_id || '').trim();
      if (fileId) {
        try { await deleteDriveFilesViaAppsScript(ctx, [fileId]); }
        catch (e) { return error('DRIVE_DELETE_FAILED','تعذّر حذف ملف المادة من Google Drive؛ لم يتم حذف سجل D1.',502,ctx.requestId,ctx.cors); }
      }
      await ctx.env.DB.batch([
        ctx.env.DB.prepare('DELETE FROM material_progress_events WHERE material_id=?').bind(id),
        ctx.env.DB.prepare('DELETE FROM material_progress WHERE material_id=?').bind(id),
        ctx.env.DB.prepare('DELETE FROM materials WHERE id=?').bind(id),
      ]);
      await writeAudit(ctx, actorId, 'delete', 'materials', id, { mode:'hard_delete', drive_file_id:fileId || null, xp_policy:'preserve_xp_events' });
      return ok(ctx, { deleted:true, id, mode:'hard_delete', driveDeleted:Boolean(fileId) });
    }

    if (table === 'subjects') {
      const materials = await queryAll(ctx.env, 'SELECT id,drive_file_id FROM materials WHERE subject_id=?', id);
      const fileIds = materials.map(r => r.drive_file_id).filter(Boolean);
      if (fileIds.length) {
        try { await deleteDriveFilesViaAppsScript(ctx, fileIds); }
        catch (e) { return error('DRIVE_DELETE_FAILED','تعذّر حذف ملفات المادة من Google Drive؛ لم يتم حذف بيانات D1.',502,ctx.requestId,ctx.cors); }
      }
      const materialIds = materials.map(r => r.id);
      const stmts = [];
      if (materialIds.length) {
        const marks = materialIds.map(() => '?').join(',');
        stmts.push(ctx.env.DB.prepare(`DELETE FROM material_progress_events WHERE material_id IN (${marks})`).bind(...materialIds));
        stmts.push(ctx.env.DB.prepare(`DELETE FROM material_progress WHERE material_id IN (${marks})`).bind(...materialIds));
      }
      stmts.push(ctx.env.DB.prepare('DELETE FROM materials WHERE subject_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM schedules WHERE subject_id=?').bind(id));
      stmts.push(ctx.env.DB.prepare('DELETE FROM subjects WHERE id=?').bind(id));
      await ctx.env.DB.batch(stmts);
      await writeAudit(ctx, actorId, 'delete', 'subjects', id, { mode:'hard_delete', materials_deleted:materials.length, drive_files_deleted:fileIds.length, xp_policy:'preserve_xp_events' });
      return ok(ctx, { deleted:true, id, mode:'hard_delete', materialsDeleted:materials.length, driveFilesDeleted:fileIds.length });
    }

    if (table === 'announcements') {
      // Announcements are ordinary content in this project: DELETE means a real
      // hard delete. Remove queued deliveries and targets first so no orphaned
      // notification records remain.
      const results = await ctx.env.DB.batch([
        ctx.env.DB.prepare('DELETE FROM notification_dispatch_queue WHERE notification_target_id IN (SELECT id FROM notification_targets WHERE announcement_id=?)').bind(id),
        ctx.env.DB.prepare('DELETE FROM notification_targets WHERE announcement_id=?').bind(id),
        ctx.env.DB.prepare('DELETE FROM announcements WHERE id=?').bind(id),
      ]);
      const result = results[results.length - 1];
      if (!result.meta?.changes) return error('ADMIN_NOT_FOUND','الإعلان غير موجود.',404,ctx.requestId,ctx.cors);
      await writeAudit(ctx, actorId, 'delete', table, id, { mode:'hard_delete', notification_targets_deleted:true });
      return ok(ctx, { deleted:true, id, mode:'hard_delete' });
    }

    if (CONTENT_TABLES.has(table)) {
      // Content deletion is intentionally permanent. Remove owned R2 media and
      // generic interactions/comments before deleting the content row.
      const mediaUrls = extractMediaUrlsFromRow(ctx, existing);
      if (mediaUrls.length) await deleteOwnedMediaUrls(ctx, mediaUrls);
      await deleteGenericContentRefs(table, id);
      const result = await ctx.env.DB.prepare(`DELETE FROM ${table} WHERE id=?`).bind(id).run();
      if (!result.meta?.changes) return error('ADMIN_NOT_FOUND','السجل غير موجود.',404,ctx.requestId,ctx.cors);
      await writeAudit(ctx, actorId, 'delete', table, id, { mode:'hard_delete', media_deleted:mediaUrls.length });
      return ok(ctx, { deleted:true, id, mode:'hard_delete', mediaDeleted:mediaUrls.length });
    }

    if (table === 'comments') {
      await ctx.env.DB.batch([
        ctx.env.DB.prepare('DELETE FROM comment_reactions WHERE comment_id=?').bind(id),
        ctx.env.DB.prepare('DELETE FROM comment_replies WHERE comment_id=?').bind(id),
        ctx.env.DB.prepare('DELETE FROM reactions WHERE content_type=? AND content_id=?').bind('comment', id),
        ctx.env.DB.prepare('DELETE FROM comments WHERE id=?').bind(id),
      ]);
      await writeAudit(ctx, actorId, 'delete', table, id, { mode:'hard_delete' });
      return ok(ctx, { deleted:true, id, mode:'hard_delete' });
    }

    // Operational records: schedules are hard-deleted. Badges remain an internal system
    // and are intentionally not exposed through the dashboard CRUD surface.
    if (table === 'schedules') {
      await ctx.env.DB.prepare('DELETE FROM schedules WHERE id=?').bind(id).run();
      await writeAudit(ctx, actorId, 'delete', table, id, { mode:'hard_delete' });
      return ok(ctx, { deleted:true, id, mode:'hard_delete' });
    }

    const result = await ctx.env.DB.prepare(`DELETE FROM ${table} WHERE id=?`).bind(id).run();
    if (!result.meta?.changes) return error('ADMIN_NOT_FOUND','السجل غير موجود.',404,ctx.requestId,ctx.cors);
    await writeAudit(ctx, actorId, 'delete', table, id, { mode:'hard_delete' });
    return ok(ctx, { deleted:true, id, mode:'hard_delete' });
  }

  return error('METHOD_NOT_ALLOWED','الطريقة غير مدعومة.',405,ctx.requestId,ctx.cors);
}

export async function adminAuthEvents(ctx) {
  const a = await adminRouteAuthOnly(ctx, 'superadmin.read');
  if (a.response) return a.response;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const rows = await queryAll(ctx.env, `SELECT e.id, e.actor_type, e.actor_id, e.event_type, e.created_at, su.user_id AS actor_user_id, su.email AS actor_email, su.display_name AS actor_name, r.name AS role_name
    FROM auth_audit_events e
    LEFT JOIN staff_users su ON su.id = e.actor_id
    LEFT JOIN roles r ON r.id = su.role_id
    WHERE e.event_type IN ('login_failed','login_locked','password_change_failed','password_change_locked')
    ORDER BY e.created_at DESC LIMIT ?`, limit);
  return ok(ctx, rows, {limit});
}

export async function adminAuditLogs(ctx) {
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const rows = await queryAll(ctx.env, `SELECT al.*, su.display_name AS actor_name, r.name AS role_name FROM audit_logs al LEFT JOIN staff_users su ON su.id=al.actor_id LEFT JOIN roles r ON r.id=su.role_id ORDER BY al.created_at DESC LIMIT ?`, limit);
  return ok(ctx, rows, {limit});
}

export async function adminSettings(ctx, id) {
  if (ctx.request.method === 'GET') return ok(ctx, await queryAll(ctx.env, 'SELECT * FROM app_settings ORDER BY key'));
  const a = await staffAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request); const key = String(body?.key || id || '').trim();
  if (!key || key.length > 128) return error('SETTING_KEY_INVALID','مفتاح الإعداد غير صالح.',400,ctx.requestId,ctx.cors);
  if (ctx.request.method !== 'PUT' && ctx.request.method !== 'PATCH' && ctx.request.method !== 'POST') return error('METHOD_NOT_ALLOWED','الطريقة غير مدعومة.',405,ctx.requestId,ctx.cors);
  const previous = key === 'Logo' ? await queryOne(ctx.env, 'SELECT value_json FROM app_settings WHERE key=?', key) : null;
  const value = JSON.stringify(body?.value ?? body?.value_json ?? null);
  await ctx.env.DB.prepare('INSERT INTO app_settings(key,value_json,updated_by,updated_at) VALUES(?,?,?,CURRENT_TIMESTAMP) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json,updated_by=excluded.updated_by,updated_at=CURRENT_TIMESTAMP').bind(key,value,a.session.staff_user_id).run();
  if (key === 'Logo') {
    try {
      const oldValue = previous ? parseJsonValue(previous.value_json, null) : null;
      if (oldValue && oldValue !== (body?.value ?? body?.value_json ?? null)) await deleteOwnedMediaUrls(ctx, [oldValue]);
    } catch (_) {}
  }
  await writeAudit(ctx,a.session.staff_user_id,'update','app_settings',key);
  return ok(ctx,{key,value_json:value});
}

export async function adminStaff(ctx, id, actorId) {
  if (ctx.request.method === 'GET') {
    const rows = await queryAll(ctx.env, `SELECT su.id,su.user_id,su.email,su.display_name,su.role_id,su.active,su.created_at,su.updated_at,su.last_login_at,r.name AS role_name FROM staff_users su JOIN roles r ON r.id=su.role_id ORDER BY su.created_at DESC LIMIT 100`);
    return ok(ctx, rows);
  }
  if (ctx.session?.staff_role_id !== 'super_admin' && actorId) { /* permission map already blocks non-super admin writes below */ }
  const body = await parseJson(ctx.request);
  if (ctx.request.method === 'POST') {
    const userId=String(body?.userId||body?.username||body?.email||'').trim(), emailRaw=String(body?.email||'').trim(), email=emailRaw?emailRaw.toLowerCase():null, name=String(body?.displayName||body?.display_name||'').trim(), password=String(body?.password||''), role=String(body?.roleId||body?.role_id||'content_manager');
    if(!userId||userId.length>128||!name||password.length<8) return error('STAFF_INPUT_INVALID','اسم المستخدم والاسم وكلمة المرور من 8 أحرف مطلوبة.',400,ctx.requestId,ctx.cors);
    if(!ADMIN_ROLE_IDS.has(role)) return error('STAFF_ROLE_INVALID','دور الإدارة غير صالح.',400,ctx.requestId,ctx.cors);
    const duplicate = await queryOne(ctx.env, 'SELECT id FROM staff_users WHERE lower(user_id)=? LIMIT 1', userId.toLowerCase());
    if (duplicate) return error('STAFF_USER_ID_TAKEN','اسم المستخدم مستخدم بالفعل.',409,ctx.requestId,ctx.cors);
    const salt=token(16), hash=await pbkdf2Hash(password,salt), sid=crypto.randomUUID();
    await ctx.env.DB.prepare('INSERT INTO staff_users(id,user_id,email,display_name,role_id,password_hash,password_salt,password_algo) VALUES(?,?,?,?,?,?,?,?)').bind(sid,userId,email,name,role,hash,salt,'pbkdf2-sha256').run();
    await writeAudit(ctx,actorId,'create','staff_users',sid,{userId,email,role}); return ok(ctx,{id:sid,user_id:userId,email,display_name:name,role_id:role},null,201);
  }
  if(!id) return error('ADMIN_ID_REQUIRED','معرّف المستخدم مطلوب.',400,ctx.requestId,ctx.cors);
  if(ctx.request.method==='PATCH') {
    const sets=[], vals=[];
    if(body?.userId||body?.username){const nextUserId=String(body.userId||body.username).trim(); if(!nextUserId||nextUserId.length>128)return error('STAFF_USER_ID_INVALID','اسم المستخدم غير صالح.',400,ctx.requestId,ctx.cors); const duplicate=await queryOne(ctx.env,'SELECT id FROM staff_users WHERE lower(user_id)=? AND id<>? LIMIT 1',nextUserId.toLowerCase(),id); if(duplicate)return error('STAFF_USER_ID_TAKEN','اسم المستخدم مستخدم بالفعل.',409,ctx.requestId,ctx.cors); sets.push('user_id=?');vals.push(nextUserId);}
    if(body?.email!==undefined){const nextEmail=String(body.email||'').trim();sets.push('email=?');vals.push(nextEmail?nextEmail.toLowerCase():null);}
    if(body?.displayName||body?.display_name){sets.push('display_name=?');vals.push(String(body.displayName||body.display_name).trim());}
    if(body?.roleId||body?.role_id){
      const nextRole=String(body.roleId||body.role_id);
      if(!ADMIN_ROLE_IDS.has(nextRole)) return error('STAFF_ROLE_INVALID','دور الإدارة غير صالح.',400,ctx.requestId,ctx.cors);
      if(id===actorId) return error('STAFF_SELF_ROLE_CHANGE_FORBIDDEN','لا يمكنك تغيير دور حسابك الحالي.',400,ctx.requestId,ctx.cors);
      sets.push('role_id=?');vals.push(nextRole);
    }
    if(body?.active!==undefined){
      if(id===actorId && !body.active) return error('STAFF_SELF_DEACTIVATE_FORBIDDEN','لا يمكنك تعطيل حسابك الحالي.',400,ctx.requestId,ctx.cors);
      sets.push('active=?');vals.push(body.active?1:0);
    }
    let passwordChanged = false;
    if(body?.password){
      const nextPassword=String(body.password);
      if(nextPassword.length<8 || nextPassword.length>256)return error('STAFF_PASSWORD_INVALID','كلمة المرور يجب أن تكون بين 8 و256 حرفًا.',400,ctx.requestId,ctx.cors);
      if(id===actorId)return error('STAFF_USE_CHANGE_PASSWORD','استخدم تغيير كلمة المرور من حسابك بدل تعديلها إداريًا.',400,ctx.requestId,ctx.cors);
      const salt=token(16);
      sets.push('password_hash=?','password_salt=?','password_algo=?','failed_login_attempts=?','locked_until=?');
      vals.push(await pbkdf2Hash(nextPassword,salt),salt,'pbkdf2-sha256',0,null);
      passwordChanged = true;
    }
    if(!sets.length)return error('ADMIN_NO_FIELDS','لم يتم إرسال أي تغييرات.',400,ctx.requestId,ctx.cors);
    vals.push(id); const result=await ctx.env.DB.prepare(`UPDATE staff_users SET ${sets.join(',')},updated_at=CURRENT_TIMESTAMP WHERE id=?`).bind(...vals).run();
    if(!result.meta?.changes)return error('ADMIN_NOT_FOUND','المستخدم غير موجود.',404,ctx.requestId,ctx.cors);
    if(passwordChanged){
      await ctx.env.DB.prepare('UPDATE sessions SET revoked_at=CURRENT_TIMESTAMP WHERE staff_user_id=? AND revoked_at IS NULL').bind(id).run();
      await recordAuthEvent(ctx,'staff',id,'password_reset_by_admin');
    }
    await writeAudit(ctx,actorId,'update','staff_users',id,{fields:sets.map(x=>x.split('=')[0]),passwordChanged});
    return ok(ctx,{updated:true,passwordSessionsRevoked:passwordChanged});
  }
  if(ctx.request.method==='DELETE'){
    if(id===actorId)return error('STAFF_SELF_DELETE_FORBIDDEN','لا يمكنك حذف حسابك الحالي.',400,ctx.requestId,ctx.cors);
    const existing=await queryOne(ctx.env,'SELECT id FROM staff_users WHERE id=?',id);
    if(!existing)return error('ADMIN_NOT_FOUND','المستخدم غير موجود.',404,ctx.requestId,ctx.cors);
    await ctx.env.DB.batch([
      ctx.env.DB.prepare('DELETE FROM sessions WHERE staff_user_id=?').bind(id),
      ctx.env.DB.prepare('UPDATE news SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
      ctx.env.DB.prepare('UPDATE events SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
      ctx.env.DB.prepare('UPDATE achievements SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
      ctx.env.DB.prepare('UPDATE announcements SET created_by=NULL WHERE created_by=?').bind(id),
      ctx.env.DB.prepare('UPDATE schedules SET created_by=NULL, updated_by=NULL WHERE created_by=? OR updated_by=?').bind(id,id),
      ctx.env.DB.prepare('UPDATE app_settings SET updated_by=NULL WHERE updated_by=?').bind(id),
    ]);
    const r=await ctx.env.DB.prepare('DELETE FROM staff_users WHERE id=?').bind(id).run();
    if(!r.meta?.changes)return error('ADMIN_NOT_FOUND','المستخدم غير موجود.',404,ctx.requestId,ctx.cors);
    await writeAudit(ctx,actorId,'delete','staff_users',id,{mode:'hard_delete'});
    return ok(ctx,{deleted:true,id,mode:'hard_delete'});
  }
  return error('METHOD_NOT_ALLOWED','الطريقة غير مدعومة.',405,ctx.requestId,ctx.cors);
}

export async function adminNotifications(ctx) {
  const a = await adminRouteAuthOnly(ctx, 'notifications.read'); if (a.response) return a.response;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const rows = await queryAll(ctx.env, `SELECT a.id, a.title, a.body, a.type, a.notification_category, a.content_type, a.content_id, a.target_department_id, a.target_semester_id, a.status, a.publish_at, a.expires_at, COUNT(nt.id) AS targets, SUM(CASE WHEN nt.read_at IS NOT NULL THEN 1 ELSE 0 END) AS reads FROM announcements a LEFT JOIN notification_targets nt ON nt.announcement_id=a.id GROUP BY a.id ORDER BY COALESCE(a.publish_at,a.created_at) DESC LIMIT ?`, limit);
  return ok(ctx, rows);
}

export async function adminNotificationSend(ctx, actorId) {
  const authResult = await adminRouteAuthOnly(ctx, 'notifications.write');
  if (authResult.response) return authResult.response;
  actorId = actorId || authResult.session.staff_user_id;

  const body = await parseJson(ctx.request);
  const announcementId = String(body?.announcementId || '').trim();
  if (!announcementId) return error('ANNOUNCEMENT_REQUIRED', 'معرّف الإعلان مطلوب.', 400, ctx.requestId, ctx.cors);

  const announcement = await queryOne(ctx.env,
    'SELECT id, status, publish_at, expires_at, target_department_id, target_semester_id FROM announcements WHERE id=?',
    announcementId);
  if (!announcement) return error('ANNOUNCEMENT_NOT_FOUND', 'الإعلان غير موجود.', 404, ctx.requestId, ctx.cors);
  if (announcement.status !== 'published') return error('ANNOUNCEMENT_NOT_PUBLISHED', 'يجب نشر الإعلان قبل إرساله.', 400, ctx.requestId, ctx.cors);
  if (announcement.publish_at && new Date(announcement.publish_at).getTime() > Date.now()) {
    return error('ANNOUNCEMENT_SCHEDULED', 'هذا الإعلان مجدول للمستقبل؛ سيُجهّز للإرسال تلقائيًا عند حلول موعده.', 409, ctx.requestId, ctx.cors);
  }
  if (announcement.expires_at && new Date(announcement.expires_at).getTime() <= Date.now()) {
    return error('ANNOUNCEMENT_EXPIRED', 'انتهت صلاحية هذا الإعلان ولا يمكن إرساله.', 409, ctx.requestId, ctx.cors);
  }

  const targetWhere = [
    's.active=1',
    's.auth_secret_hash IS NOT NULL',
    '(? IS NULL OR s.department_id=?)',
    '(? IS NULL OR s.current_semester_id=?)',
  ].join(' AND ');
  const targetBinds = [
    announcement.target_department_id || null,
    announcement.target_department_id || null,
    announcement.target_semester_id || null,
    announcement.target_semester_id || null,
  ];

  // One set-based insert replaces the previous per-student N+1 loop.
  // randomblob() is used only for opaque internal IDs; UUID format is not required by the schema.
  const targetInsert = await ctx.env.DB.prepare(`
    INSERT INTO notification_targets (id, announcement_id, student_id)
    SELECT lower(hex(randomblob(16))), ?, s.id
    FROM students s
    WHERE ${targetWhere}
      AND NOT EXISTS (
        SELECT 1 FROM notification_targets nt
        WHERE nt.announcement_id=? AND nt.student_id=s.id
      )
  `).bind(announcementId, ...targetBinds, announcementId).run();

  // Queue push deliveries once per active device, and one in-app delivery per target.
  // NOT EXISTS keeps repeated sends idempotent even though the legacy queue table has
  // no uniqueness constraint on delivery rows.
  await ctx.env.DB.batch([
    ctx.env.DB.prepare(`
      INSERT OR IGNORE INTO notification_dispatch_queue (id, notification_target_id, device_id, channel)
      SELECT lower(hex(randomblob(16))), nt.id, nd.id, 'push'
      FROM notification_targets nt
      JOIN notification_devices nd ON nd.student_id=nt.student_id AND nd.active=1
      WHERE nt.announcement_id=?
        AND NOT EXISTS (
          SELECT 1 FROM notification_dispatch_queue q
          WHERE q.notification_target_id=nt.id AND q.device_id=nd.id AND q.channel='push'
        )
    `).bind(announcementId),
    ctx.env.DB.prepare(`
      INSERT OR IGNORE INTO notification_dispatch_queue (id, notification_target_id, channel)
      SELECT lower(hex(randomblob(16))), nt.id, 'in_app'
      FROM notification_targets nt
      WHERE nt.announcement_id=?
        AND NOT EXISTS (
          SELECT 1 FROM notification_dispatch_queue q
          WHERE q.notification_target_id=nt.id AND q.device_id IS NULL AND q.channel='in_app'
        )
    `).bind(announcementId),
  ]);

  const counts = await queryOne(ctx.env,
    'SELECT COUNT(*) AS targets FROM notification_targets WHERE announcement_id=?',
    announcementId);
  const targetCount = Number(counts?.targets || 0);
  const newTargets = Number(targetInsert?.meta?.changes || 0);

  await writeAudit(ctx, actorId, 'send', 'notifications', announcementId, {
    targets: targetCount,
    newTargets,
    mode: 'set_based_idempotent',
  });
  return ok(ctx, {
    announcementId,
    targets: targetCount,
    newTargets,
    pushQueued: true,
    idempotent: true,
  });
}

export async function adminRouteAuthOnly(ctx, permissionName) {
  return requireAdminPermission(ctx, permissionName);
}

export async function adminEinoUsage(ctx) {
  const a = await requireAdminPermission(ctx, 'dashboard.read');
  if (a.response) return a.response;
  const hours = clampInt(ctx.url.searchParams.get('hours'), 24, 1, 168);
  const since = new Date(Date.now() - hours * 3600000).toISOString();
  const rows = await queryAll(ctx.env, `
    SELECT bucket_started_at AS bucketStartedAt, event_type AS eventType, actor_type AS actorType,
           event_count AS eventCount, total_latency_ms AS totalLatencyMs, last_event_at AS lastEventAt
      FROM eino_telemetry
     WHERE bucket_started_at >= ?
     ORDER BY bucket_started_at DESC, event_type ASC, actor_type ASC
     LIMIT 2000`, since);
  const summaryRows = await queryAll(ctx.env, `
    SELECT event_type AS eventType, actor_type AS actorType,
           SUM(event_count) AS eventCount, SUM(total_latency_ms) AS totalLatencyMs
      FROM eino_telemetry
     WHERE bucket_started_at >= ?
     GROUP BY event_type, actor_type
     ORDER BY eventCount DESC`, since);
  return ok(ctx, {
    hours,
    since,
    limits: {
      window: EINO_WINDOW_LIMIT,
      windowSeconds: EINO_WINDOW_SECONDS,
      studentDaily: positiveInt(ctx.env.EINO_STUDENT_DAILY_LIMIT, EINO_STUDENT_DAILY_LIMIT_DEFAULT),
      guestDaily: positiveInt(ctx.env.EINO_GUEST_DAILY_LIMIT, EINO_GUEST_DAILY_LIMIT_DEFAULT),
      globalDaily: positiveInt(ctx.env.EINO_GLOBAL_DAILY_LIMIT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT),
    },
    summary: summaryRows.map(r => ({
      eventType: r.eventType, actorType: r.actorType, eventCount: Number(r.eventCount || 0),
      averageLatencyMs: r.eventCount ? Math.round(Number(r.totalLatencyMs || 0) / Number(r.eventCount)) : 0,
    })),
    buckets: rows.map(r => ({
      ...r, eventCount: Number(r.eventCount || 0), totalLatencyMs: Number(r.totalLatencyMs || 0),
    })),
  });
}


export async function adminEinoMonitor(ctx) {
  const a = await requireAdminPermission(ctx, 'superadmin.read');
  if (a.response) return a.response;
  const hours = clampInt(ctx.url.searchParams.get('hours'), 24, 1, 168);
  const limit = clampInt(ctx.url.searchParams.get('limit'), 100, 1, 200);
  const since = new Date(Date.now() - hours * 3600000).toISOString();
  const [summary, providers, tasks, recent, quota, legacy] = await Promise.all([
    queryAll(ctx.env, `SELECT status, COUNT(*) AS count, ROUND(AVG(latency_ms)) AS avgLatencyMs, SUM(cost_units) AS costUnits FROM eino_request_telemetry WHERE occurred_at >= ? GROUP BY status ORDER BY count DESC`, since),
    queryAll(ctx.env, `SELECT COALESCE(provider,'unknown') AS provider, COUNT(*) AS requests, SUM(CASE WHEN status='success' THEN 1 ELSE 0 END) AS successes, SUM(CASE WHEN status!='success' THEN 1 ELSE 0 END) AS failures, ROUND(AVG(latency_ms)) AS avgLatencyMs, SUM(cost_units) AS costUnits FROM eino_request_telemetry WHERE occurred_at >= ? GROUP BY provider ORDER BY requests DESC`, since),
    queryAll(ctx.env, `SELECT COALESCE(task,capability) AS task, COUNT(*) AS requests, SUM(CASE WHEN status='success' THEN 1 ELSE 0 END) AS successes, ROUND(AVG(latency_ms)) AS avgLatencyMs, SUM(cost_units) AS costUnits FROM eino_request_telemetry WHERE occurred_at >= ? GROUP BY COALESCE(task,capability) ORDER BY requests DESC`, since),
    queryAll(ctx.env, `SELECT id, occurred_at AS occurredAt, actor_type AS actorType, capability, task, status, provider, model, latency_ms AS latencyMs, cost_units AS costUnits, fallback, error_code AS errorCode FROM eino_request_telemetry WHERE occurred_at >= ? ORDER BY occurred_at DESC LIMIT ?`, since, limit),
    queryAll(ctx.env, `SELECT bucket_type AS bucketType, SUM(request_count) AS units FROM eino_quota_usage WHERE bucket_started_at >= ? GROUP BY bucket_type ORDER BY bucket_type`, since),
    queryAll(ctx.env, `SELECT event_type AS eventType, actor_type AS actorType, SUM(event_count) AS count, ROUND(SUM(total_latency_ms)/NULLIF(SUM(event_count),0)) AS avgLatencyMs FROM eino_telemetry WHERE bucket_started_at >= ? GROUP BY event_type, actor_type ORDER BY count DESC`, since),
  ]);
  return ok(ctx, {
    hours, since, privacy: { prompts: false, responses: false, studentIds: false, ipAddresses: false, fileContents: false, requestIdsAreRandom: true, retentionDays: 14 },
    limits: { window: EINO_WINDOW_LIMIT, windowSeconds: EINO_WINDOW_SECONDS, studentDaily: positiveInt(ctx.env.EINO_STUDENT_DAILY_LIMIT, EINO_STUDENT_DAILY_LIMIT_DEFAULT), guestDaily: positiveInt(ctx.env.EINO_GUEST_DAILY_LIMIT, EINO_GUEST_DAILY_LIMIT_DEFAULT), globalDaily: positiveInt(ctx.env.EINO_GLOBAL_DAILY_LIMIT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT) },
    summary: summary.map(r => ({status:r.status,count:Number(r.count||0),avgLatencyMs:Number(r.avgLatencyMs||0),costUnits:Number(r.costUnits||0)})),
    providers: providers.map(r => ({provider:r.provider,requests:Number(r.requests||0),successes:Number(r.successes||0),failures:Number(r.failures||0),avgLatencyMs:Number(r.avgLatencyMs||0),costUnits:Number(r.costUnits||0)})),
    tasks: tasks.map(r => ({task:r.task,requests:Number(r.requests||0),successes:Number(r.successes||0),avgLatencyMs:Number(r.avgLatencyMs||0),costUnits:Number(r.costUnits||0)})),
    recent: recent.map(r => ({...r,latencyMs:Number(r.latencyMs||0),costUnits:Number(r.costUnits||0),fallback:Boolean(r.fallback)})),
    quota: quota.map(r => ({bucketType:r.bucketType,units:Number(r.units||0)})),
    legacy: legacy.map(r => ({...r,count:Number(r.count||0),avgLatencyMs:Number(r.avgLatencyMs||0)})),
  });
}
