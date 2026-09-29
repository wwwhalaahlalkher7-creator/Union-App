import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { staffAuth, studentAuth } from './auth.js';

const INTERACTION_RULES = { comment: { limit: 10, minutes: 10 }, reply: { limit: 15, minutes: 10 }, reaction: { limit: 40, minutes: 10 } };
const ALLOWED_REACTIONS = new Set(['like','helpful','love','celebrate']);
const CONTENT_TYPE_ALIASES = Object.freeze({
  news: 'news',
  event: 'event',
  events: 'event',
  activity: 'activity',
  activities: 'activity',
  announcement: 'announcement',
  announcements: 'announcement',
  achievement: 'achievement',
  achievements: 'achievement',
});
const ALLOWED_CONTENT_TYPES = new Set(Object.values(CONTENT_TYPE_ALIASES));
export function canonicalContentType(value) {
  return CONTENT_TYPE_ALIASES[String(value || '').trim().toLowerCase()] || null;
}

export async function contentIsCommentable(ctx, type, id) {
  type = canonicalContentType(type);
  if (!ALLOWED_CONTENT_TYPES.has(type) || !id) return false;
  const table = type === 'event' ? 'events' : type === 'activity' ? 'activities' : type === 'announcement' ? 'announcements' : type === 'achievement' ? 'achievements' : 'news';
  const dateColumn = ['events', 'activities'].includes(table) ? 'event_at' : table === 'achievements' ? 'achieved_at' : 'publish_at';
  const expiry = ['news', 'announcements'].includes(table) ? ' AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)' : '';
  const row = await queryOne(ctx.env, `SELECT id FROM ${table} WHERE id=? AND status='published' AND (${dateColumn} IS NULL OR ${dateColumn} <= CURRENT_TIMESTAMP)${expiry} LIMIT 1`, id);
  return Boolean(row);
}

export async function interactionAllowed(ctx, studentId, action) {
  const rule = INTERACTION_RULES[action]; const now = Date.now(); const windowMs = rule.minutes * 60 * 1000;
  const bucket = new Date(Math.floor(now / windowMs) * windowMs).toISOString(); const id = await sha256(`${studentId}:${action}:${bucket}`);
  await ctx.env.DB.prepare(`INSERT INTO interaction_rate_limits(id,student_id,action,window_started_at,count) VALUES(?,?,?,?,1) ON CONFLICT(student_id,action,window_started_at) DO UPDATE SET count=count+1`).bind(id,studentId,action,bucket).run();
  const row = await queryOne(ctx.env, 'SELECT count FROM interaction_rate_limits WHERE id=?', id);
  return !row || Number(row.count) <= rule.limit;
}

export async function comments(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const studentId = a.session.student_id;
  const parts = ctx.path.split('/');
  const rawType = parts[2];
  const id = parts[3];
  const type = canonicalContentType(rawType);
  if (!type) return error('CONTENT_TYPE_INVALID','نوع المحتوى غير مدعوم.',400,ctx.requestId,ctx.cors);
  const limit = clampInt(ctx.url.searchParams.get('limit'),20,1,50); const offset = clampInt(ctx.url.searchParams.get('offset'),0,0,10000);
  const rows = await queryAll(ctx.env, `SELECT c.*, s.full_name,
      (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id=c.id) AS reaction_count,
      (SELECT cr2.reaction FROM comment_reactions cr2 WHERE cr2.comment_id=c.id AND cr2.student_id=?) AS my_reaction
    FROM comments c JOIN students s ON s.id=c.student_id
    WHERE c.content_type=? AND c.content_id=? AND c.status='visible'
    ORDER BY c.created_at DESC, c.id DESC LIMIT ? OFFSET ?`,
    studentId, type, id, limit, offset);
  const total = await queryOne(ctx.env, `SELECT COUNT(*) AS count FROM comments WHERE content_type=? AND content_id=? AND status='visible'`, type,id);
  return ok(ctx,rows,{count:rows.length,total:Number(total?.count||0),offset,limit});
}

export async function replies(ctx) {
  const id=ctx.path.split('/')[2]; const limit=clampInt(ctx.url.searchParams.get('limit'),20,1,50); const offset=clampInt(ctx.url.searchParams.get('offset'),0,0,10000);
  const comment=await queryOne(ctx.env,`SELECT id FROM comments WHERE id=? AND status='visible'`,id); if(!comment) return error('COMMENT_NOT_FOUND','التعليق غير موجود.',404,ctx.requestId,ctx.cors);
  const rows=await queryAll(ctx.env,`SELECT r.*, s.full_name FROM comment_replies r JOIN students s ON s.id=r.student_id WHERE r.comment_id=? AND r.status='visible' ORDER BY r.created_at ASC LIMIT ? OFFSET ?`,id,limit,offset);
  return ok(ctx,rows,{count:rows.length,offset,limit});
}

export async function createComment(ctx) {
  const a=await studentAuth(ctx); if(a.response) return a.response; const parts=ctx.path.split('/');
  const type = canonicalContentType(parts[2]);
  if(!type) return error('CONTENT_TYPE_INVALID','نوع المحتوى غير مدعوم.',400,ctx.requestId,ctx.cors);
  const body=await parseJson(ctx.request); const text=String(body?.body||'').trim(); if(!text || text.length>2000) return error('COMMENT_INVALID','نص التعليق غير صالح.',400,ctx.requestId,ctx.cors);
  if(!(await contentIsCommentable(ctx, parts[2], parts[3]))) return error('CONTENT_NOT_FOUND','المحتوى غير موجود أو غير متاح للتعليق حاليًا.',404,ctx.requestId,ctx.cors);
  if(!(await interactionAllowed(ctx,a.session.student_id,'comment'))) return error('RATE_LIMITED','تم تجاوز حد التعليقات مؤقتًا. حاول لاحقًا.',429,ctx.requestId,ctx.cors);
  const id=crypto.randomUUID(); await ctx.env.DB.prepare('INSERT INTO comments (id,student_id,content_type,content_id,body) VALUES (?,?,?,?,?)').bind(id,a.session.student_id,type,parts[3],text).run();
  return ok(ctx,{id,body:text,status:'visible'},null,201);
}

export async function createReply(ctx) {
  const a=await studentAuth(ctx); if(a.response) return a.response; const id=ctx.path.split('/')[2]; const body=await parseJson(ctx.request); const text=String(body?.body||'').trim();
  if(!text || text.length>2000) return error('REPLY_INVALID','نص الرد غير صالح.',400,ctx.requestId,ctx.cors); if(!(await interactionAllowed(ctx,a.session.student_id,'reply'))) return error('RATE_LIMITED','تم تجاوز حد الردود مؤقتًا. حاول لاحقًا.',429,ctx.requestId,ctx.cors);
  const comment=await queryOne(ctx.env,`SELECT id FROM comments WHERE id=? AND status='visible'`,id); if(!comment) return error('COMMENT_NOT_FOUND','التعليق غير موجود.',404,ctx.requestId,ctx.cors);
  const replyId=crypto.randomUUID(); await ctx.env.DB.prepare('INSERT INTO comment_replies (id,comment_id,student_id,body) VALUES (?,?,?,?)').bind(replyId,id,a.session.student_id,text).run(); return ok(ctx,{id:replyId,commentId:id,body:text,status:'visible'},null,201);
}

export async function reaction(ctx) {
  const a=await studentAuth(ctx); if(a.response) return a.response; const parts=ctx.path.split('/'); const type=canonicalContentType(parts[2]); if(!type) return error('CONTENT_TYPE_INVALID','نوع المحتوى غير مدعوم.',400,ctx.requestId,ctx.cors);
  const body=await parseJson(ctx.request); const value=String(body?.reaction||'').trim().toLowerCase(); if(!ALLOWED_REACTIONS.has(value)) return error('REACTION_INVALID','نوع التفاعل غير مدعوم.',400,ctx.requestId,ctx.cors);
  if(!(await contentIsCommentable(ctx, parts[2], parts[3]))) return error('CONTENT_NOT_FOUND','المحتوى غير موجود أو غير متاح للتفاعل حاليًا.',404,ctx.requestId,ctx.cors);
  if(!(await interactionAllowed(ctx,a.session.student_id,'reaction'))) return error('RATE_LIMITED','تم تجاوز حد التفاعلات مؤقتًا. حاول لاحقًا.',429,ctx.requestId,ctx.cors);
  await ctx.env.DB.prepare('INSERT INTO reactions (id,student_id,content_type,content_id,reaction) VALUES (?,?,?,?,?) ON CONFLICT(student_id,content_type,content_id) DO UPDATE SET reaction=excluded.reaction').bind(crypto.randomUUID(),a.session.student_id,type,parts[3],value).run(); return ok(ctx,{reaction:value});
}

export async function commentReaction(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const id = ctx.path.split('/')[2];
  const body = await parseJson(ctx.request);
  const value = String(body?.reaction || 'like').trim().toLowerCase();
  if (!ALLOWED_REACTIONS.has(value)) return error('REACTION_INVALID','نوع التفاعل غير مدعوم.',400,ctx.requestId,ctx.cors);
  const comment = await queryOne(ctx.env, "SELECT id FROM comments WHERE id=? AND status='visible'", id);
  if (!comment) return error('COMMENT_NOT_FOUND','التعليق غير موجود.',404,ctx.requestId,ctx.cors);
  if (!(await interactionAllowed(ctx, a.session.student_id, 'reaction'))) return error('RATE_LIMITED','تم تجاوز حد التفاعلات مؤقتًا. حاول لاحقًا.',429,ctx.requestId,ctx.cors);
  await ctx.env.DB.prepare('INSERT INTO comment_reactions (id,student_id,comment_id,reaction) VALUES (?,?,?,?) ON CONFLICT(student_id,comment_id) DO UPDATE SET reaction=excluded.reaction,updated_at=CURRENT_TIMESTAMP').bind(crypto.randomUUID(), a.session.student_id, id, value).run();
  return ok(ctx, {reaction:value});
}

export async function deleteComment(ctx,id) { const a=await studentAuth(ctx); if(a.response) return a.response; const result=await ctx.env.DB.prepare("UPDATE comments SET status='deleted',updated_at=CURRENT_TIMESTAMP WHERE id=? AND student_id=? AND status='visible'").bind(id,a.session.student_id).run(); if(!result.meta?.changes) return error('COMMENT_NOT_FOUND','التعليق غير موجود أو لا يمكنك حذفه.',404,ctx.requestId,ctx.cors); return ok(ctx,{deleted:true}); }
