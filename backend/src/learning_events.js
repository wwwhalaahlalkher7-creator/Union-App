import { ok, error, parseJson, queryAll, queryOne, clampInt, XP_DAILY_CAP, XP_LEVEL_BASE } from './core.js';
import { studentAuth } from './auth.js';
import { requireAdminPermission, writeAudit } from './admin.js';

const DESIGNS = new Set(['standard', 'challenge', 'checklist']);

function parseConfig(value) {
  if (!value) return {};
  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value;
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (_) {
    return {};
  }
}

function studentCanSee(event, session) {
  return event.status === 'published'
    && (!event.publish_at || new Date(event.publish_at).getTime() <= Date.now())
    && (!event.expires_at || new Date(event.expires_at).getTime() > Date.now())
    && (!event.target_department_id || event.target_department_id === session.department_id)
    && (!event.target_semester_id || event.target_semester_id === session.current_semester_id);
}

export async function learningEvents(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const rows = await queryAll(ctx.env, `
    SELECT le.id, le.title, le.description, le.design, le.config_json, le.xp_reward,
           le.publish_at, le.expires_at, le.created_at,
           CASE WHEN lec.id IS NULL THEN 0 ELSE 1 END AS completed
      FROM learning_events le
      LEFT JOIN learning_event_completions lec
        ON lec.event_id = le.id AND lec.student_id = ?
     WHERE le.status='published'
       AND (le.publish_at IS NULL OR le.publish_at <= CURRENT_TIMESTAMP)
       AND (le.expires_at IS NULL OR le.expires_at > CURRENT_TIMESTAMP)
       AND (le.target_department_id IS NULL OR le.target_department_id = ?)
       AND (le.target_semester_id IS NULL OR le.target_semester_id = ?)
     ORDER BY COALESCE(le.publish_at, le.created_at) DESC
     LIMIT ?`,
    a.session.student_id, a.session.department_id, a.session.current_semester_id || null, limit);
  return ok(ctx, rows.map(row => ({ ...row, config: parseConfig(row.config_json), completed: Number(row.completed) === 1 })));
}

export async function learningEvent(ctx, id) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const row = await queryOne(ctx.env, `SELECT le.*, CASE WHEN lec.id IS NULL THEN 0 ELSE 1 END AS completed
    FROM learning_events le
    LEFT JOIN learning_event_completions lec ON lec.event_id=le.id AND lec.student_id=?
    WHERE le.id=?`, a.session.student_id, id);
  if (!row || !studentCanSee(row, a.session)) return error('LEARNING_EVENT_NOT_FOUND', 'الحدث غير موجود أو لم يعد متاحًا.', 404, ctx.requestId, ctx.cors);
  return ok(ctx, { ...row, config: parseConfig(row.config_json), completed: Number(row.completed) === 1 });
}

export async function completeLearningEvent(ctx, id) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const event = await queryOne(ctx.env, 'SELECT * FROM learning_events WHERE id=?', id);
  if (!event || !studentCanSee(event, a.session)) return error('LEARNING_EVENT_NOT_FOUND', 'الحدث غير موجود أو لم يعد متاحًا.', 404, ctx.requestId, ctx.cors);
  const existing = await queryOne(ctx.env, 'SELECT id FROM learning_event_completions WHERE event_id=? AND student_id=?', id, a.session.student_id);
  if (existing) return ok(ctx, { completed: true, xpAwarded: 0, alreadyCompleted: true });

  const xp = Math.min(100, Math.max(0, Number(event.xp_reward || 0)));
  if (!xp) return error('LEARNING_EVENT_NO_REWARD', 'هذا الحدث لا يحتوي على مكافأة XP.', 422, ctx.requestId, ctx.cors);
  const today = await queryOne(ctx.env, `SELECT COALESCE(SUM(xp),0) AS total FROM xp_events WHERE student_id=? AND created_at>=date('now')`, a.session.student_id);
  if (Number(today?.total || 0) + xp > XP_DAILY_CAP) return error('XP_DAILY_CAP_REACHED', 'وصلت إلى الحد اليومي للـXP. حاول إكمال الحدث غدًا.', 429, ctx.requestId, ctx.cors);

  const insert = await ctx.env.DB.prepare(`INSERT INTO learning_event_completions(id,event_id,student_id) VALUES(?,?,?)
    ON CONFLICT(event_id,student_id) DO NOTHING`).bind(crypto.randomUUID(), id, a.session.student_id).run();
  if (!Number(insert.meta?.changes || 0)) return ok(ctx, { completed: true, xpAwarded: 0, alreadyCompleted: true });

  const award = await ctx.env.DB.prepare(`
    INSERT INTO xp_events(id,student_id,event_type,source_id,xp)
    SELECT ?,?,'learning_event_complete',?,?
    WHERE (SELECT COALESCE(SUM(xp),0) FROM xp_events WHERE student_id=? AND created_at>=date('now')) + ? <= ?
    ON CONFLICT(student_id,event_type,source_id) DO NOTHING`).bind(
      crypto.randomUUID(), a.session.student_id, id, xp, a.session.student_id, xp, XP_DAILY_CAP).run();
  const awarded = Number(award.meta?.changes || 0) > 0 ? xp : 0;
  const total = await queryOne(ctx.env, 'SELECT COALESCE(SUM(xp),0) AS xp_total FROM xp_events WHERE student_id=?', a.session.student_id);
  const totalXp = Number(total?.xp_total || 0);
  const level = Math.floor(totalXp / XP_LEVEL_BASE) + 1;
  await ctx.env.DB.prepare(`INSERT INTO student_stats(student_id,xp_total,level) VALUES(?,?,?)
    ON CONFLICT(student_id) DO UPDATE SET xp_total=excluded.xp_total, level=excluded.level, updated_at=CURRENT_TIMESTAMP`)
    .bind(a.session.student_id, totalXp, level).run();
  return ok(ctx, { completed: true, xpAwarded: awarded, alreadyCompleted: false, xpTotal: totalXp, level });
}

async function publishLearningEvent(ctx, eventId, actorId) {
  const event = await queryOne(ctx.env, 'SELECT * FROM learning_events WHERE id=?', eventId);
  if (!event) return error('LEARNING_EVENT_NOT_FOUND', 'الحدث غير موجود.', 404, ctx.requestId, ctx.cors);
  const title = String(event.title || '').trim();
  const body = `${String(event.description || '').trim()}${event.description ? '\n\n' : ''}🎁 يمكنك اكتساب ${Number(event.xp_reward || 0)} XP من إكمال هذا الحدث.`;
  let announcement = await queryOne(ctx.env, 'SELECT id FROM announcements WHERE learning_event_id=? LIMIT 1', eventId);
  if (!announcement) {
    const announcementId = crypto.randomUUID();
    await ctx.env.DB.prepare(`INSERT INTO announcements
      (id,title,body,type,target_department_id,target_semester_id,publish_at,expires_at,status,created_by,learning_event_id)
      VALUES(?,?,?,?,?,?,?,?, 'published',?,?)`).bind(
      announcementId, title, body, 'learning_event', event.target_department_id || null,
      event.target_semester_id || null, event.publish_at || null, event.expires_at || null, actorId, eventId).run();
    announcement = { id: announcementId };
  } else {
    await ctx.env.DB.prepare(`UPDATE announcements SET title=?,body=?,type='learning_event',target_department_id=?,target_semester_id=?,publish_at=?,expires_at=?,status='published',updated_at=CURRENT_TIMESTAMP WHERE id=?`)
      .bind(title, body, event.target_department_id || null, event.target_semester_id || null, event.publish_at || null, event.expires_at || null, announcement.id).run();
  }

  const targetWhere = `s.active=1 AND (? IS NULL OR s.department_id=?) AND (? IS NULL OR s.current_semester_id=?)`;
  await ctx.env.DB.prepare(`INSERT INTO notification_targets(id,announcement_id,student_id)
    SELECT lower(hex(randomblob(16))),?,s.id FROM students s
    WHERE ${targetWhere}
      AND NOT EXISTS(SELECT 1 FROM notification_targets nt WHERE nt.announcement_id=? AND nt.student_id=s.id)`)
    .bind(announcement.id, ...[event.target_department_id || null,event.target_department_id || null,event.target_semester_id || null,event.target_semester_id || null], announcement.id).run();

  await ctx.env.DB.batch([
    ctx.env.DB.prepare(`INSERT OR IGNORE INTO notification_dispatch_queue(id,notification_target_id,device_id,channel)
      SELECT lower(hex(randomblob(16))),nt.id,nd.id,'push' FROM notification_targets nt
      JOIN notification_devices nd ON nd.student_id=nt.student_id AND nd.active=1
      WHERE nt.announcement_id=? AND NOT EXISTS(SELECT 1 FROM notification_dispatch_queue q WHERE q.notification_target_id=nt.id AND q.device_id=nd.id AND q.channel='push')`).bind(announcement.id),
    ctx.env.DB.prepare(`INSERT OR IGNORE INTO notification_dispatch_queue(id,notification_target_id,channel)
      SELECT lower(hex(randomblob(16))),nt.id,'in_app' FROM notification_targets nt
      WHERE nt.announcement_id=? AND NOT EXISTS(SELECT 1 FROM notification_dispatch_queue q WHERE q.notification_target_id=nt.id AND q.device_id IS NULL AND q.channel='in_app')`).bind(announcement.id),
  ]);

  await writeAudit(ctx, actorId, 'publish', 'learning_events', eventId, { announcementId: announcement.id, xpReward: Number(event.xp_reward || 0) });
  return announcement.id;
}

export async function adminLearningEvents(ctx, id = null) {
  const method = ctx.request.method;
  const permission = method === 'GET' ? 'notifications.read' : 'notifications.write';
  const a = await requireAdminPermission(ctx, permission); if (a.response) return a.response;
  if (method === 'GET') {
    const limit = clampInt(ctx.url.searchParams.get('limit'), 100, 1, 100);
    const rows = await queryAll(ctx.env, `SELECT le.*, COUNT(lec.id) AS completions
      FROM learning_events le LEFT JOIN learning_event_completions lec ON lec.event_id=le.id
      GROUP BY le.id ORDER BY COALESCE(le.publish_at,le.created_at) DESC LIMIT ?`, limit);
    return ok(ctx, rows.map(r => ({ ...r, config: parseConfig(r.config_json), completions: Number(r.completions || 0) })));
  }
  if (method === 'POST') {
    const body = await parseJson(ctx.request) || {};
    const title = String(body.title || '').trim();
    const description = String(body.description || '').trim();
    const design = String(body.design || 'standard').trim();
    const xp = Number(body.xp_reward);
    if (!title) return error('LEARNING_EVENT_TITLE_REQUIRED','اسم الحدث مطلوب.',400,ctx.requestId,ctx.cors);
    if (!DESIGNS.has(design)) return error('LEARNING_EVENT_DESIGN_INVALID','تصميم الحدث غير مدعوم.',400,ctx.requestId,ctx.cors);
    if (!Number.isInteger(xp) || xp < 0 || xp > 100) return error('LEARNING_EVENT_XP_INVALID','مكافأة الحدث يجب أن تكون بين 0 و100 XP.',400,ctx.requestId,ctx.cors);
    let config = {};
    if (body.config_json != null) {
      try { config = typeof body.config_json === 'string' ? JSON.parse(body.config_json) : body.config_json; } catch (_) { return error('LEARNING_EVENT_CONFIG_INVALID','إعدادات تصميم الحدث غير صالحة.',400,ctx.requestId,ctx.cors); }
    }
    const id = crypto.randomUUID();
    const status = body.status === 'published' ? 'published' : 'draft';
    await ctx.env.DB.prepare(`INSERT INTO learning_events
      (id,title,description,design,config_json,xp_reward,target_department_id,target_semester_id,publish_at,expires_at,status,created_by)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?)`).bind(
      id,title,description,design,JSON.stringify(config || {}),xp,body.target_department_id || null,body.target_semester_id || null,
      body.publish_at || null,body.expires_at || null,status,a.session.staff_user_id).run();
    if (status === 'published') await publishLearningEvent(ctx, id, a.session.staff_user_id);
    return ok(ctx, await queryOne(ctx.env, 'SELECT * FROM learning_events WHERE id=?', id), null, 201);
  }
  if (!id) return error('ADMIN_ID_REQUIRED','معرّف الحدث مطلوب.',400,ctx.requestId,ctx.cors);
  const existing = await queryOne(ctx.env, 'SELECT * FROM learning_events WHERE id=?', id);
  if (!existing) return error('LEARNING_EVENT_NOT_FOUND','الحدث غير موجود.',404,ctx.requestId,ctx.cors);
  if (method === 'PATCH') {
    const body = await parseJson(ctx.request) || {};
    const fields = {};
    for (const key of ['title','description','design','xp_reward','target_department_id','target_semester_id','publish_at','expires_at','status']) if (Object.prototype.hasOwnProperty.call(body,key)) fields[key] = body[key] === '' ? null : body[key];
    if (body.config_json !== undefined) fields.config_json = typeof body.config_json === 'string' ? body.config_json : JSON.stringify(body.config_json || {});
    if (fields.design && !DESIGNS.has(String(fields.design))) return error('LEARNING_EVENT_DESIGN_INVALID','تصميم الحدث غير مدعوم.',400,ctx.requestId,ctx.cors);
    if (fields.xp_reward !== undefined && (!Number.isInteger(Number(fields.xp_reward)) || Number(fields.xp_reward)<0 || Number(fields.xp_reward)>100)) return error('LEARNING_EVENT_XP_INVALID','مكافأة الحدث يجب أن تكون بين 0 و100 XP.',400,ctx.requestId,ctx.cors);
    if (fields.status && !['draft','published'].includes(String(fields.status))) return error('LEARNING_EVENT_STATUS_INVALID','حالة الحدث غير مدعومة.',400,ctx.requestId,ctx.cors);
    fields.updated_at = new Date().toISOString();
    if (!Object.keys(fields).length) return error('ADMIN_NO_FIELDS','لم يتم إرسال أي تغييرات.',400,ctx.requestId,ctx.cors);
    await ctx.env.DB.prepare(`UPDATE learning_events SET ${Object.keys(fields).map(k=>`${k}=?`).join(',')} WHERE id=?`).bind(...Object.values(fields),id).run();
    const updated = await queryOne(ctx.env,'SELECT * FROM learning_events WHERE id=?',id);
    if (String(updated.status || '') === 'published') await publishLearningEvent(ctx,id,a.session.staff_user_id);
    return ok(ctx, updated);
  }
  if (method === 'DELETE') {
    const announcement = await queryOne(ctx.env,'SELECT id FROM announcements WHERE learning_event_id=? LIMIT 1',id);
    if (announcement) {
      await ctx.env.DB.batch([
        ctx.env.DB.prepare('DELETE FROM notification_dispatch_queue WHERE notification_target_id IN (SELECT id FROM notification_targets WHERE announcement_id=?)').bind(announcement.id),
        ctx.env.DB.prepare('DELETE FROM notification_targets WHERE announcement_id=?').bind(announcement.id),
        ctx.env.DB.prepare('DELETE FROM announcements WHERE id=?').bind(announcement.id),
      ]);
    }
    await ctx.env.DB.batch([
      ctx.env.DB.prepare('DELETE FROM learning_event_completions WHERE event_id=?').bind(id),
      ctx.env.DB.prepare('DELETE FROM learning_events WHERE id=?').bind(id),
    ]);
    await writeAudit(ctx,a.session.staff_user_id,'delete','learning_events',id,{mode:'hard_delete'});
    return ok(ctx,{deleted:true,id});
  }
  return error('METHOD_NOT_ALLOWED','الطريقة غير مدعومة.',405,ctx.requestId,ctx.cors);
}
