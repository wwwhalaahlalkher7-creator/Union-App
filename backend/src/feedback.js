import { ok, error, parseJson, queryOne } from './core.js';
import { studentAuth } from './auth.js';

const CATEGORIES = new Set(['suggestion', 'bug', 'content', 'other']);

export async function createStudentFeedback(ctx) {
  const auth = await studentAuth(ctx);
  if (auth.response) return auth.response;

  const body = await parseJson(ctx.request) || {};
  const category = String(body.category || '').trim();
  const title = String(body.title || '').replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
  const details = String(body.details || '').replace(/\r\n?/g, '\n').trim();
  const screen = String(body.screen || '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, 120) || null;

  if (!CATEGORIES.has(category)) return error('FEEDBACK_CATEGORY_INVALID', 'اختر نوع المقترح أو البلاغ.', 400, ctx.requestId, ctx.cors);
  if (title.length < 3 || title.length > 120) return error('FEEDBACK_TITLE_INVALID', 'العنوان مطلوب ويجب ألا يتجاوز 120 حرفًا.', 400, ctx.requestId, ctx.cors);
  if (details.length < 10 || details.length > 3000) return error('FEEDBACK_DETAILS_INVALID', 'اكتب تفاصيل واضحة من 10 إلى 3000 حرف.', 400, ctx.requestId, ctx.cors);
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(details)) return error('FEEDBACK_DETAILS_INVALID', 'التفاصيل تحتوي على محارف غير مدعومة.', 400, ctx.requestId, ctx.cors);

  const recent = await queryOne(ctx.env, `SELECT COUNT(*) AS count FROM student_feedback_reports
    WHERE student_id=? AND created_at >= datetime('now','-1 day')`, auth.session.student_id);
  if (Number(recent?.count || 0) >= 10) {
    return error('FEEDBACK_RATE_LIMITED', 'وصلت إلى الحد اليومي للإرسال. حاول مجددًا لاحقًا.', 429, ctx.requestId, ctx.cors);
  }

  const id = crypto.randomUUID();
  await ctx.env.DB.prepare(`INSERT INTO student_feedback_reports
    (id, student_id, category, title, details, screen) VALUES (?, ?, ?, ?, ?, ?)`)
    .bind(id, auth.session.student_id, category, title, details, screen).run();

  return ok(ctx, { id, category, title, status: 'open', createdAt: new Date().toISOString() }, null, 201);
}
