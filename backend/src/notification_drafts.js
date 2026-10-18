import { queryOne, makeId } from './core.js';

export async function createOrRefreshContentNotificationDraft(ctx, table, row, actorId) {
  if (!row || !['schedules', 'materials', 'achievements'].includes(table)) return null;
  let category, contentType, title, body, departmentId = null, semesterId = null;
  if (table === 'schedules') {
    const refs = await queryOne(ctx.env, `SELECT d.name_ar AS department_name, s.name_ar AS semester_name, sub.name_ar AS subject_name
      FROM departments d, semesters s LEFT JOIN subjects sub ON sub.id=?
      WHERE d.id=? AND s.id=?`, row.subject_id || null, row.department_id, row.semester_id);
    category = 'schedule'; contentType = 'schedule';
    title = 'تم تحديث الجدول الدراسي';
    body = `تم إنشاء أو تحديث الجدول الدراسي${refs?.subject_name ? ` لمادة ${refs.subject_name}` : ''}${refs?.department_name ? ` بقسم ${refs.department_name}` : ''}${refs?.semester_name ? ` — ${refs.semester_name}` : ''}. افتح التطبيق للاطلاع على التفاصيل.`;
    departmentId = row.department_id || null; semesterId = row.semester_id || null;
  } else if (table === 'materials') {
    const refs = await queryOne(ctx.env, `SELECT sub.name_ar AS subject_name, d.id AS department_id, sem.id AS semester_id, d.name_ar AS department_name, sem.name_ar AS semester_name
      FROM subjects sub JOIN departments d ON d.id=sub.department_id JOIN semesters sem ON sem.id=sub.semester_id WHERE sub.id=?`, row.subject_id);
    category = 'material'; contentType = 'material';
    title = 'مادة دراسية جديدة';
    body = `أُضيفت أو حُدّثت مادة دراسية${refs?.subject_name ? `: ${refs.subject_name}` : ''}${row.title ? ` — ${row.title}` : ''}. افتح التطبيق للاطلاع على المادة.`;
    departmentId = refs?.department_id || null; semesterId = refs?.semester_id || null;
  } else {
    category = 'achievement'; contentType = 'achievement';
    title = 'إنجاز جديد يستحق الاحتفاء';
    body = `${row.title || 'تم نشر إنجاز جديد'}. افتح التطبيق للاطلاع على التفاصيل.`;
  }
  const existing = await queryOne(ctx.env, `SELECT id FROM announcements WHERE content_type=? AND content_id=? AND status='draft' ORDER BY created_at DESC LIMIT 1`, contentType, row.id);
  if (existing) {
    await ctx.env.DB.prepare(`UPDATE announcements SET title=?, body=?, type=?, notification_category=?, target_department_id=?, target_semester_id=?, updated_at=CURRENT_TIMESTAMP WHERE id=? AND status='draft'`)
      .bind(title, body, category, category, departmentId, semesterId, existing.id).run();
    return existing.id;
  }
  const notificationId = makeId('notification');
  await ctx.env.DB.prepare(`INSERT INTO announcements (id,title,body,type,target_department_id,target_semester_id,status,created_by,notification_category,content_type,content_id)
    VALUES (?,?,?,?,?,?,'draft',?,?,?,?)`).bind(notificationId,title,body,category,departmentId,semesterId,actorId,category,contentType,row.id).run();
  return notificationId;
}

