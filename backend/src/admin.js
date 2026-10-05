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
import { recordAuthEvent, staffAuth } from './auth.js';
import { deleteOwnedMediaUrls, extractMediaUrlsFromRow, markOwnedMediaAttached } from './media.js';
import { deleteDriveFilesViaAppsScript } from './drive.js';

const ADMIN_ROLE_PERMISSIONS = Object.freeze({
  super_admin: ['*'],
  content_manager: ['content.read', 'content.write', 'dashboard.read'],
  academic_manager: ['academic.read', 'academic.write', 'dashboard.read'],
  moderator: ['moderation.read', 'moderation.write', 'notifications.read', 'notifications.write', 'dashboard.read'],
});
const ADMIN_ROLE_IDS = new Set(Object.keys(ADMIN_ROLE_PERMISSIONS));

const ADMIN_FIELDS = {
  news: ['title','body','image_url','images_json','publish_at','expires_at','status','category','publisher'],
  announcements: ['title','body','type','target_department_id','target_semester_id','publish_at','expires_at','status'],
  events: ['title','body','image_url','images_json','category','event_at','end_at','location','publisher','status'],
  achievements: ['title','description','intro','highlights_title','highlights','badge','publisher','image_url','images_json','achieved_at','status'],
  subjects: ['semester_id','department_id','code','name_ar','name_en','active','sort_order'],
  materials: ['subject_id','title','description','drive_file_id','drive_url','mime_type','size_bytes','active','sort_order','drive_parent_id','drive_modified_at','drive_web_view_url','pinned','source'],
  schedules: ['semester_id','department_id','subject_id','day_of_week','start_time','end_time','room','lecturer','active'],
  students: ['student_number','full_name','email','department_id','current_semester_id','active'],
  badges: ['name_ar','description_ar','icon_url','rule_type','rule_value','active','sort_order'],
  comments: ['student_id','content_type','content_id','body','status'],
};

const CONTENT_STATUS_VALUES = Object.freeze(new Set(['draft', 'published']));
const CONTENT_TABLES = Object.freeze(new Set(['news', 'events', 'announcements', 'achievements']));
const CONTENT_UPDATED_BY_TABLES = Object.freeze(new Set(['news', 'events', 'achievements']));


const ADMIN_SELECT_COLUMNS = {
  news: 'id,title,body,image_url,images_json,publish_at,expires_at,status,category,publisher,created_by,updated_by,created_at,updated_at',
  announcements: 'id,title,body,type,target_department_id,target_semester_id,publish_at,expires_at,status,created_by,created_at,updated_at',
  events: 'id,title,body,image_url,images_json,category,event_at,end_at,location,publisher,status,created_by,updated_by,created_at,updated_at',
  achievements: 'id,title,description,intro,highlights_title,highlights,badge,publisher,image_url,images_json,achieved_at,status,created_by,updated_by,created_at,updated_at',
  subjects: 'id,semester_id,department_id,code,name_ar,name_en,active,sort_order',
  materials: 'id,subject_id,title,description,drive_file_id,drive_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_modified_at,drive_web_view_url,pinned,source,created_at,updated_at',
  schedules: 'id,semester_id,department_id,subject_id,day_of_week,start_time,end_time,room,lecturer,active,created_by,updated_by,updated_at',
  students: 'id,student_number,full_name,email,department_id,current_semester_id,active,CASE WHEN auth_secret_hash IS NULL THEN 0 ELSE 1 END AS registered,created_at,updated_at',
  badges: 'id,name_ar,description_ar,icon_url,rule_type,rule_value,active,sort_order,created_at,updated_at',
  comments: 'id,student_id,content_type,content_id,body,status,created_at,updated_at',
};
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

export function hasAdminPermission(roleId, permissionName) {
  const allowed = ADMIN_ROLE_PERMISSIONS[roleId] || [];
  return allowed.includes('*') || allowed.includes(permissionName);
}

export async function requireAdminPermission(ctx, permissionName) {
  const a = await staffAuth(ctx);
  if (a.response) return a;
  if (!a.session.staff_user_id || a.session.staff_active !== 1) {
    return { response: error('STAFF_AUTH_REQUIRED', 'صلاحيات الإدارة مطلوبة.', 403, ctx.requestId, ctx.cors) };
  }
  if (!hasAdminPermission(a.session.staff_role_id, permissionName)) {
    return { response: error('FORBIDDEN', 'ليس لديك صلاحية لتنفيذ هذا الإجراء.', 403, ctx.requestId, ctx.cors) };
  }
  return a;
}

export async function adminRoute(ctx) {
  const a = await requireAdminPermission(ctx, adminPermission(ctx.path, ctx.request.method));
  if (a.response) return a.response;

  const parts = ctx.path.split('/').filter(Boolean);
  const resource = parts[1] || '';
  const id = parts[2] || null;
  if (resource === 'audit-logs' && ctx.request.method === 'GET') return adminAuditLogs(ctx);
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
  if (path.includes('/staff')) return method === 'GET' ? 'superadmin.read' : 'superadmin.write';
  if (path.includes('/settings')) return method === 'GET' ? 'superadmin.read' : 'superadmin.write';
  if (path.includes('/audit-logs')) return method === 'GET' ? 'superadmin.read' : 'superadmin.write';
  if (path.includes('/notifications') || path.includes('/announcements')) return method === 'GET' ? 'notifications.read' : 'notifications.write';
  if (path.includes('/students') || path.includes('/subjects') || path.includes('/materials') || path.includes('/schedule')) return method === 'GET' ? 'academic.read' : 'academic.write';
  if (path.includes('/comments') || path.includes('/moderation')) return method === 'GET' ? 'moderation.read' : 'moderation.write';
  return method === 'GET' ? 'content.read' : 'content.write';
}

export function adminResourceTable(resource) {
  const map = { news:'news', announcements:'announcements', events:'events', achievements:'achievements', subjects:'subjects', materials:'materials', schedule:'schedules', schedules:'schedules', students:'students', badges:'badges', comments:'comments' };
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
  }

  return null;
}

export async function writeAudit(ctx, actorId, action, resourceType, resourceId, metadata = {}) {
  await ctx.env.DB.prepare('INSERT INTO audit_logs (id, actor_type, actor_id, action, resource_type, resource_id, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .bind(crypto.randomUUID(), 'staff', actorId, action, resourceType, resourceId, JSON.stringify(metadata || {})).run();
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
    if (CONTENT_TABLES.has(table) && fields.status !== undefined && !CONTENT_STATUS_VALUES.has(String(fields.status))) return error('CONTENT_STATUS_INVALID','حالة المحتوى غير مدعومة.',400,ctx.requestId,ctx.cors);
    if (table === 'badges') {
      const allowedRules = new Set(['xp_total','level','completed_materials','progress_events']);
      if (fields.rule_type && !allowedRules.has(String(fields.rule_type))) return error('BADGE_RULE_INVALID','نوع قاعدة الشارة غير مدعوم.',400,ctx.requestId,ctx.cors);
      if (fields.rule_value != null && (!Number.isInteger(Number(fields.rule_value)) || Number(fields.rule_value)<=0)) return error('BADGE_RULE_VALUE_INVALID','قيمة قاعدة الشارة يجب أن تكون رقمًا صحيحًا موجبًا.',400,ctx.requestId,ctx.cors);
    }
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
    return ok(ctx, await queryOne(ctx.env, `SELECT * FROM ${table} WHERE id=?`, id), null, 201);
  }
  if (!id) return error('ADMIN_ID_REQUIRED','معرّف السجل مطلوب.',400,ctx.requestId,ctx.cors);
  if (ctx.request.method === 'PATCH') {
    const body = await parseJson(ctx.request); const fields = cleanAdminPayload(table, body);
    if (CONTENT_TABLES.has(table) && fields.status !== undefined && !CONTENT_STATUS_VALUES.has(String(fields.status))) return error('CONTENT_STATUS_INVALID','حالة المحتوى غير مدعومة.',400,ctx.requestId,ctx.cors);
    if (table === 'badges') {
      const allowedRules = new Set(['xp_total','level','completed_materials','progress_events']);
      if (fields.rule_type && !allowedRules.has(String(fields.rule_type))) return error('BADGE_RULE_INVALID','نوع قاعدة الشارة غير مدعوم.',400,ctx.requestId,ctx.cors);
      if (fields.rule_value != null && (!Number.isInteger(Number(fields.rule_value)) || Number(fields.rule_value)<=0)) return error('BADGE_RULE_VALUE_INVALID','قيمة قاعدة الشارة يجب أن تكون رقمًا صحيحًا موجبًا.',400,ctx.requestId,ctx.cors);
    }
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
    return ok(ctx, updatedRow);
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

    if (table === 'badges') {
      return error('BADGE_ADMIN_DISABLED','الشارات نظام داخلي ثابت ولا تُدار من لوحة التحكم.',403,ctx.requestId,ctx.cors);
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
  const rows = await queryAll(ctx.env, `SELECT a.id, a.title, a.type, a.status, a.publish_at, a.expires_at, COUNT(nt.id) AS targets, SUM(CASE WHEN nt.read_at IS NOT NULL THEN 1 ELSE 0 END) AS reads FROM announcements a LEFT JOIN notification_targets nt ON nt.announcement_id=a.id GROUP BY a.id ORDER BY COALESCE(a.publish_at,a.created_at) DESC LIMIT ?`, limit);
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
    'SELECT id, status, target_department_id, target_semester_id FROM announcements WHERE id=?',
    announcementId);
  if (!announcement) return error('ANNOUNCEMENT_NOT_FOUND', 'الإعلان غير موجود.', 404, ctx.requestId, ctx.cors);
  if (announcement.status !== 'published') return error('ANNOUNCEMENT_NOT_PUBLISHED', 'يجب نشر الإعلان قبل إرساله.', 400, ctx.requestId, ctx.cors);

  const targetWhere = [
    's.active=1',
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
