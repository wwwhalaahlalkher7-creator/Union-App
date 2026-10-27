import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { studentAuth } from './auth.js';
export async function semesters(ctx) { const rows = await queryAll(ctx.env, 'SELECT * FROM semesters WHERE active = 1 ORDER BY academic_year DESC, number'); return ok(ctx, rows); }

export async function departments(ctx) { const rows = await queryAll(ctx.env, 'SELECT * FROM departments WHERE active = 1 ORDER BY sort_order, name_ar'); return ok(ctx, rows); }

export async function subjects(ctx) {
  const semesterId = ctx.url.searchParams.get('semesterId'); const departmentId = ctx.url.searchParams.get('departmentId');
  const a = await studentAuth(ctx, false);
  if (a?.response) return a.response;
  const effectiveDepartment = a?.session?.department_id || departmentId;
  if (!effectiveDepartment) return error('DEPARTMENT_REQUIRED', 'التخصص مطلوب.', 400, ctx.requestId, ctx.cors);
  const rows = await queryAll(ctx.env, 'SELECT * FROM subjects WHERE active = 1 AND department_id = ? AND (? IS NULL OR semester_id = ?) ORDER BY sort_order, name_ar', effectiveDepartment, semesterId, semesterId);
  return ok(ctx, rows);
}

export async function effectiveStudentSemester(ctx, session, requested) {
  if (requested) {
    const row = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE id = ? AND active = 1', requested);
    if (!row) return { error: error('SEMESTER_NOT_FOUND', 'الفصل الدراسي غير موجود.', 404, ctx.requestId, ctx.cors) };
    return { id: requested };
  }
  if (session.current_semester_id) {
    const row = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE id = ? AND active = 1', session.current_semester_id);
    if (row) return { id: row.id };
  }
  const current = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE active = 1 ORDER BY is_current DESC, academic_year DESC, number DESC LIMIT 1');
  return { id: current?.id || null };
}

export async function effectiveMaterialSemester(ctx, session, requested) {
  if (requested) {
    // Materials intentionally allow browsing historical semesters. A previous
    // semester may be archived/inactive while its study files remain useful.
    const row = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE id = ?', requested);
    if (!row) return { error: error('SEMESTER_NOT_FOUND', 'الفصل الدراسي غير موجود.', 404, ctx.requestId, ctx.cors) };
    return { id: requested };
  }
  if (session.current_semester_id) {
    const row = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE id = ?', session.current_semester_id);
    if (row) return { id: row.id };
  }
  const current = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE active = 1 ORDER BY is_current DESC, academic_year DESC, number DESC LIMIT 1');
  return { id: current?.id || null };
}

export async function materials(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const requestedSemester = ctx.url.searchParams.get('semesterId');
  const subjectId = ctx.url.searchParams.get('subjectId');
  const limit = clampInt(ctx.url.searchParams.get('limit'), 50, 1, 100);
  const semester = await effectiveMaterialSemester(ctx, a.session, requestedSemester);
  if (semester.error) return semester.error;
  const rows = await queryAll(ctx.env, `SELECT m.id, m.subject_id, m.title, m.description, m.mime_type, m.size_bytes, m.pinned, m.sort_order, m.created_at, m.updated_at, s.code AS subject_code, s.name_ar AS subject_name, s.name_en AS subject_name_en, s.semester_id, s.department_id
    FROM materials m JOIN subjects s ON s.id = m.subject_id
    WHERE m.active = 1 AND s.active = 1 AND s.department_id = ?
      AND (? IS NULL OR s.semester_id = ?)
      AND (? IS NULL OR m.subject_id = ?)
    ORDER BY m.pinned DESC, s.sort_order, s.name_ar, m.sort_order, m.title LIMIT ?`,
    a.session.department_id, semester.id, semester.id, subjectId, subjectId, limit);
  const data = rows.map(row => ({
    ...row,
    file_url: `/api/v1/materials/${encodeURIComponent(row.id)}/file`,
  }));
  return ok(ctx, data, { semesterId: semester.id, departmentId: a.session.department_id, count: data.length, limit });
}

export async function materialById(ctx, id) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const row = await queryOne(ctx.env, 'SELECT m.*, s.name_ar AS subject_name, s.name_en AS subject_name_en, s.code AS subject_code, s.semester_id, s.department_id FROM materials m JOIN subjects s ON s.id = m.subject_id WHERE m.id = ? AND m.active = 1 AND s.active = 1 AND s.department_id = ?', id, a.session.department_id);
  if (!row) return error('MATERIAL_NOT_FOUND', 'المادة غير موجودة أو غير متاحة لهذا الطالب.', 404, ctx.requestId, ctx.cors);
  delete row.drive_file_id;
  delete row.drive_url;
  delete row.drive_web_view_url;
  row.file_url = `/api/v1/materials/${encodeURIComponent(row.id)}/file`;
  return ok(ctx, row);
}

export async function materialFile(ctx, id) {
  const a = await studentAuth(ctx);
  if (a.response) return a.response;

  const row = await queryOne(ctx.env, `
    SELECT m.id, m.drive_file_id, m.drive_url, m.mime_type, m.size_bytes
    FROM materials m
    JOIN subjects s ON s.id = m.subject_id
    WHERE m.id = ? AND m.active = 1 AND s.active = 1 AND s.department_id = ?
  `, id, a.session.department_id);

  if (!row) return error('MATERIAL_NOT_FOUND', 'الملف غير موجود أو غير متاح لهذا الطالب.', 404, ctx.requestId, ctx.cors);

  let upstreamUrl = null;
  const driveFileId = row.drive_file_id ? encodeURIComponent(row.drive_file_id) : null;
  if (driveFileId) {
    // The student never receives this URL. The Worker is the only component
    // that talks to the upstream storage provider.
    upstreamUrl = `https://drive.google.com/uc?export=download&id=${driveFileId}`;
  } else if (row.drive_url) {
    try {
      const candidate = new URL(row.drive_url);
      if (candidate.hostname === 'drive.google.com' || candidate.hostname.endsWith('.googleusercontent.com')) {
        upstreamUrl = candidate.toString();
      }
    } catch (_) {}
  }

  if (!upstreamUrl) {
    return error('MATERIAL_FILE_UNAVAILABLE', 'ملف المادة غير متاح حاليًا.', 404, ctx.requestId, ctx.cors);
  }

  const upstreamHeaders = new Headers();
  const range = ctx.request.headers.get('Range');
  if (range) upstreamHeaders.set('Range', range);
  upstreamHeaders.set('Accept', 'application/pdf');

  const upstream = await fetch(upstreamUrl, {
    method: 'GET',
    headers: upstreamHeaders,
    redirect: 'follow',
  });

  const upstreamContentType = (upstream.headers.get('content-type') || '').toLowerCase();
  const storedMimeType = String(row.mime_type || '').toLowerCase();
  const contentType = upstreamContentType || storedMimeType || 'application/pdf';
  const upstreamLooksPdf = upstreamContentType.includes('pdf') ||
    (!upstreamContentType || upstreamContentType.includes('octet-stream')) && storedMimeType.includes('pdf');
  if (!upstream.ok || !upstreamLooksPdf) {
    console.error(`[${ctx.requestId}] material file upstream failed`, {
      materialId: id,
      status: upstream.status,
      contentType,
    });
    return error('MATERIAL_FILE_UNAVAILABLE', 'تعذر تحميل ملف المادة حاليًا.', 502, ctx.requestId, ctx.cors);
  }

  const headers = {
    ...ctx.cors,
    'content-type': 'application/pdf',
    'content-disposition': 'inline',
    'cache-control': 'private, max-age=300',
    'x-content-type-options': 'nosniff',
    'accept-ranges': upstream.headers.get('accept-ranges') || 'bytes',
  };

  for (const name of ['content-length', 'content-range', 'etag', 'last-modified']) {
    const value = upstream.headers.get(name);
    if (value) headers[name] = value;
  }

  return new Response(upstream.body, {
    status: upstream.status,
    headers,
  });
}

export async function schedule(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const requestedSemester = ctx.url.searchParams.get('semesterId');
  const effective = await effectiveStudentSemester(ctx, a.session, requestedSemester);
  if (effective.error) return effective.error;
  if (!effective.id) return ok(ctx, { semester: null, department: null, items: [], days: [] });

  const semester = await queryOne(ctx.env,
    'SELECT id, name_ar, name_en, academic_year, number FROM semesters WHERE id = ? AND active = 1',
    effective.id);
  const department = await queryOne(ctx.env,
    'SELECT id, name_ar, name_en, code FROM departments WHERE id = ? AND active = 1',
    a.session.department_id);
  const rows = await queryAll(ctx.env, `
    SELECT sch.id, sch.semester_id, sch.department_id, sch.subject_id,
           sch.day_of_week, sch.start_time, sch.end_time, sch.room, sch.lecturer,
           s.code AS subject_code, s.name_ar AS subject_name, s.name_en AS subject_name_en
    FROM schedules sch
    LEFT JOIN subjects s ON s.id = sch.subject_id
    WHERE sch.active = 1 AND sch.department_id = ? AND sch.semester_id = ?
    ORDER BY sch.day_of_week, sch.start_time, sch.end_time, s.sort_order, s.name_ar`,
    a.session.department_id, effective.id);

  const items = rows.map(row => ({
    id: row.id, semesterId: row.semester_id, departmentId: row.department_id,
    subjectId: row.subject_id, subjectCode: row.subject_code,
    subjectName: row.subject_name || 'مادة غير محددة', subjectNameEn: row.subject_name_en || 'Unassigned subject',
    dayOfWeek: row.day_of_week, startTime: row.start_time, endTime: row.end_time,
    room: row.room, lecturer: row.lecturer,
  }));
  const days = [...new Set(items.map(item => item.dayOfWeek))].sort((a, b) => a - b);
  return ok(ctx, { semester, department, items, days }, {
    semesterId: effective.id, departmentId: a.session.department_id, count: items.length,
  });
}

export async function progress(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const rows = await queryAll(ctx.env, `SELECT mp.*, m.title AS material_title, s.name_ar AS subject_name
    FROM material_progress mp
    JOIN materials m ON m.id = mp.material_id
    JOIN subjects s ON s.id = m.subject_id
    WHERE mp.student_id = ?
    ORDER BY mp.last_opened_at DESC LIMIT 100`, a.session.student_id);
  const summary = await queryOne(ctx.env, `SELECT
      COUNT(*) AS started,
      SUM(CASE WHEN progress_percent >= 100 THEN 1 ELSE 0 END) AS completed,
      COALESCE(SUM(active_seconds), 0) AS active_seconds,
      COALESCE(MAX(progress_percent), 0) AS max_progress
    FROM material_progress WHERE student_id = ?`, a.session.student_id);
  return ok(ctx, rows, { summary: summary || { started: 0, completed: 0, active_seconds: 0, max_progress: 0 } });
}

export async function xp(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  // xp_events is the source of truth. student_stats is a cached aggregate and
  // may be missing for older students or after a partial migration. Rebuild it
  // on read so the XP screen cannot silently stay at zero.
  const [events, aggregate] = await Promise.all([
    queryAll(ctx.env, 'SELECT event_type, source_id, xp, created_at FROM xp_events WHERE student_id = ? ORDER BY created_at DESC LIMIT 100', a.session.student_id),
    queryOne(ctx.env, 'SELECT COALESCE(SUM(xp), 0) AS xp_total FROM xp_events WHERE student_id = ?', a.session.student_id),
  ]);
  const total = Math.max(0, Number(aggregate?.xp_total || 0));
  const level = calculateLevel(total);
  await ctx.env.DB.prepare(`
    INSERT INTO student_stats (student_id, xp_total, level)
    VALUES (?, ?, ?)
    ON CONFLICT(student_id) DO UPDATE SET
      xp_total = excluded.xp_total,
      level = excluded.level,
      updated_at = CURRENT_TIMESTAMP
  `).bind(a.session.student_id, total, level).run();
  const levelStartXp = XP_LEVEL_BASE * (level - 1);
  const levelXp = Math.max(0, total - levelStartXp);
  return ok(ctx, {
    stats: { xp_total: total, level, level_xp: levelXp, next_level_xp: XP_LEVEL_BASE, level_start_xp: levelStartXp },
    events,
  });
}

export async function badges(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;

  // Badge eligibility is derived from immutable activity metrics. The catalogue
  // read and the award write are deliberately independent so a single stale
  // student_badges row/table cannot make the whole profile/system screen fail.
  const defaultBadges = [
    { id:'badge-first-step', name_ar:'البداية', description_ar:'ابدأ أول تقدم دراسي موثق.', icon_url:null, rule_type:'progress_events', rule_value:1, active:1, sort_order:10 },
    { id:'badge-first-complete', name_ar:'أول إنجاز', description_ar:'أكمل أول ملف دراسي.', icon_url:null, rule_type:'completed_materials', rule_value:1, active:1, sort_order:20 },
    { id:'badge-five-complete', name_ar:'خمسة ملفات', description_ar:'أكمل 5 ملفات دراسية.', icon_url:null, rule_type:'completed_materials', rule_value:5, active:1, sort_order:30 },
    { id:'badge-ten-complete', name_ar:'عشرة ملفات', description_ar:'أكمل 10 ملفات دراسية.', icon_url:null, rule_type:'completed_materials', rule_value:10, active:1, sort_order:40 },
    { id:'badge-level-5', name_ar:'المستوى 5', description_ar:'وصل إلى المستوى الخامس.', icon_url:null, rule_type:'level', rule_value:5, active:1, sort_order:50 },
    { id:'badge-500-xp', name_ar:'500 XP', description_ar:'اجمع 500 XP من أنشطتك الدراسية.', icon_url:null, rule_type:'xp_total', rule_value:500, active:1, sort_order:60 },
  ];

  let definitions = defaultBadges;
  try {
    const rows = await queryAll(ctx.env, 'SELECT id, name_ar, description_ar, icon_url, rule_type, rule_value, active, sort_order FROM badges WHERE active=1 ORDER BY sort_order ASC, id ASC');
    if (rows.length) definitions = rows;
  } catch (e) {
    console.error(`[${ctx.requestId}] badge catalogue fallback`, e);
  }

  const metrics = await queryOne(ctx.env, `
    SELECT
      (SELECT COALESCE(SUM(xp),0) FROM xp_events WHERE student_id=?) AS xp_total,
      (SELECT COUNT(*) FROM material_progress_events WHERE student_id=?) AS progress_events,
      (SELECT COUNT(*) FROM material_progress WHERE student_id=? AND progress_percent>=100) AS completed_materials
  `, a.session.student_id, a.session.student_id, a.session.student_id);
  const xpTotal = Number(metrics?.xp_total || 0);
  const values = {
    xp_total: xpTotal,
    level: calculateLevel(xpTotal),
    progress_events: Number(metrics?.progress_events || 0),
    completed_materials: Number(metrics?.completed_materials || 0),
  };

  const eligible = definitions.filter((badge) => {
    const current = Number(values[badge.rule_type] || 0);
    return Number(badge.rule_value || 0) > 0 && current >= Number(badge.rule_value);
  });

  let awardedRows = [];
  try {
    if (eligible.length) {
      const results = await ctx.env.DB.batch(eligible.map((badge) =>
        ctx.env.DB.prepare('INSERT INTO student_badges(student_id,badge_id) VALUES(?,?) ON CONFLICT(student_id,badge_id) DO NOTHING').bind(a.session.student_id, badge.id)
      ));
      awardedRows = eligible.filter((_, i) => Number(results[i]?.meta?.changes || 0) > 0).map((badge) => badge.id);
    }
  } catch (e) {
    console.error(`[${ctx.requestId}] badge award write failed`, e);
  }

  let awardedAt = new Map();
  try {
    const rows = await queryAll(ctx.env, 'SELECT badge_id, awarded_at FROM student_badges WHERE student_id=?', a.session.student_id);
    awardedAt = new Map(rows.map(row => [String(row.badge_id), row.awarded_at]));
  } catch (e) {
    console.error(`[${ctx.requestId}] badge award read failed`, e);
  }

  const rows = definitions.map((badge) => ({
    ...badge,
    earned: eligible.some((item) => item.id === badge.id) || awardedAt.has(String(badge.id)),
    awarded_at: awardedAt.get(String(badge.id)) || null,
  }));
  return ok(ctx, {
    badges: rows,
    earnedCount: rows.filter(r => r.earned).length,
    totalCount: rows.length,
    newlyAwarded: awardedRows,
  });
}

export async function materialProgress(ctx, materialId) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request) || {};
  const eventType = String(body.eventType || 'progress').trim().toLowerCase();
  const requested = Number.parseInt(body.progressPercent, 10);
  const percent = Number.isFinite(requested) ? Math.min(100, Math.max(0, requested)) : 0;
  const material = await queryOne(ctx.env, `SELECT m.id FROM materials m
    JOIN subjects s ON s.id = m.subject_id
    WHERE m.id = ? AND m.active = 1 AND s.active = 1 AND s.department_id = ?`, materialId, a.session.department_id);
  if (!material) return error('MATERIAL_NOT_FOUND', 'المادة غير موجودة أو غير متاحة لهذا الطالب.', 404, ctx.requestId, ctx.cors);

  const existing = await queryOne(ctx.env, 'SELECT * FROM material_progress WHERE student_id = ? AND material_id = ?', a.session.student_id, materialId);
  const now = Date.now();
  const lastOpened = existing?.last_opened_at ? new Date(existing.last_opened_at).getTime() : null;
  const lastProgress = existing?.last_progress_at ? new Date(existing.last_progress_at).getTime() : null;
  const elapsedSinceOpen = lastOpened ? Math.max(0, Math.floor((now - lastOpened) / 1000)) : 0;
  const boundedElapsed = Math.min(elapsedSinceOpen, 300);

  if (!['open', 'progress', 'complete'].includes(eventType)) {
    return error('PROGRESS_EVENT_INVALID', 'نوع تقدم غير صالح.', 400, ctx.requestId, ctx.cors);
  }

  if (eventType !== 'open' && !existing) {
    return error('PROGRESS_OPEN_REQUIRED', 'افتح الملف أولًا قبل تسجيل التقدم.', 409, ctx.requestId, ctx.cors);
  }

  if (eventType !== 'open' && lastProgress && now - lastProgress < 15000) {
    return error('PROGRESS_RATE_LIMITED', 'انتظر قليلًا قبل تسجيل تقدم جديد.', 429, ctx.requestId, ctx.cors);
  }

  let nextPercent = existing?.progress_percent || 0;
  if (eventType === 'open') {
    nextPercent = nextPercent;
  } else {
    if (percent < nextPercent) {
      return ok(ctx, { materialId, progressPercent: nextPercent, completed: nextPercent >= 100, activeSeconds: existing?.active_seconds || 0, accepted: false, reason: 'progress_cannot_decrease', xpAwarded: 0 });
    }
    if (percent > nextPercent + 25) {
      return error('PROGRESS_STEP_TOO_LARGE', 'لا يمكن القفز في التقدم بهذه السرعة. سجّل المراحل تدريجيًا.', 422, ctx.requestId, ctx.cors);
    }
    if (percent >= 100 && (existing?.active_seconds || 0) + boundedElapsed < 45) {
      return error('PROGRESS_COMPLETION_TOO_EARLY', 'أكمل وقتًا كافيًا في الملف قبل تسجيل الإكمال.', 422, ctx.requestId, ctx.cors);
    }
    nextPercent = Math.max(nextPercent, percent);
  }

  const activeSeconds = Math.min((existing?.active_seconds || 0) + boundedElapsed, 8 * 60 * 60);
  const completed = nextPercent >= 100;
  if (existing) {
    await ctx.env.DB.prepare(`UPDATE material_progress SET progress_percent = ?, active_seconds = ?, last_opened_at = CURRENT_TIMESTAMP,
      last_progress_at = CASE WHEN ? = 1 THEN CURRENT_TIMESTAMP ELSE last_progress_at END,
      completed_at = CASE WHEN ? = 1 THEN COALESCE(completed_at, CURRENT_TIMESTAMP) ELSE completed_at END
      WHERE student_id = ? AND material_id = ?`)
      .bind(nextPercent, activeSeconds, eventType === 'open' ? 0 : 1, completed ? 1 : 0, a.session.student_id, materialId).run();
  } else {
    await ctx.env.DB.prepare(`INSERT INTO material_progress
      (id, student_id, material_id, progress_percent, first_opened_at, last_opened_at, completed_at, active_seconds, last_progress_at)
      VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?)`)
      .bind(crypto.randomUUID(), a.session.student_id, materialId, nextPercent, completed ? new Date().toISOString() : null, activeSeconds, eventType === 'open' ? null : new Date().toISOString()).run();
  }

  await ctx.env.DB.prepare(`INSERT INTO material_progress_events
    (id, student_id, material_id, event_type, progress_percent, active_seconds)
    VALUES (?, ?, ?, ?, ?, ?)`)
    .bind(crypto.randomUUID(), a.session.student_id, materialId, eventType, nextPercent, boundedElapsed).run();

  const xpAwarded = await awardProgressXp(ctx, a.session.student_id, materialId, existing?.progress_percent || 0, nextPercent);
  const newlyAwardedBadges = await evaluateBadges(ctx, a.session.student_id);
  return ok(ctx, { materialId, progressPercent: nextPercent, completed, activeSeconds, accepted: true, xpAwarded, newlyAwardedBadges });
}

export function calculateLevel(totalXp) {
  const safe = Math.max(0, Number(totalXp) || 0);
  return Math.floor(safe / XP_LEVEL_BASE) + 1;
}

export async function awardProgressXp(ctx, studentId, materialId, previousPercent, nextPercent) {
  if (nextPercent <= previousPercent) return 0;

  const milestones = [
    { percent: 25, xp: 10, eventType: 'material_progress_25' },
    { percent: 50, xp: 10, eventType: 'material_progress_50' },
    { percent: 75, xp: 15, eventType: 'material_progress_75' },
    { percent: 100, xp: 25, eventType: 'material_complete' },
  ];
  const crossed = milestones.filter((m) => previousPercent < m.percent && nextPercent >= m.percent);
  if (!crossed.length) return 0;

  // The INSERT ... SELECT condition is evaluated inside the same D1 batch
  // transaction as the milestone inserts. This makes the daily cap an
  // atomic database rule instead of a read-then-write race in JavaScript.
  const statements = crossed.map((milestone) => ctx.env.DB.prepare(`
    INSERT INTO xp_events (id, student_id, event_type, source_id, xp)
    SELECT ?, ?, ?, ?, ?
    WHERE (
      SELECT COALESCE(SUM(xp), 0)
      FROM xp_events
      WHERE student_id = ? AND created_at >= date('now')
    ) + ? <= ?
    ON CONFLICT(student_id, event_type, source_id) DO NOTHING
  `).bind(
    crypto.randomUUID(),
    studentId,
    milestone.eventType,
    materialId,
    milestone.xp,
    studentId,
    milestone.xp,
    XP_DAILY_CAP,
  ));

  const results = await ctx.env.DB.batch(statements);
  const awarded = crossed.reduce((sum, milestone, index) => {
    const changed = Number(results[index]?.meta?.changes || 0);
    return sum + (changed > 0 ? milestone.xp : 0);
  }, 0);
  if (awarded <= 0) return 0;

  const total = await queryOne(ctx.env, 'SELECT COALESCE(SUM(xp),0) AS xp_total FROM xp_events WHERE student_id=?', studentId);
  const totalXp = Number(total?.xp_total || 0);
  await ctx.env.DB.prepare(`
    INSERT INTO student_stats (student_id, xp_total, level)
    VALUES (?, ?, ?)
    ON CONFLICT(student_id) DO UPDATE SET
      xp_total = excluded.xp_total,
      level = excluded.level,
      updated_at = CURRENT_TIMESTAMP
  `).bind(studentId, totalXp, calculateLevel(totalXp)).run();

  return awarded;
}

export async function evaluateBadges(ctx, studentId) {
  const badgeRows = await queryAll(ctx.env,
    'SELECT id, rule_type, rule_value FROM badges WHERE active=1 ORDER BY sort_order ASC, id ASC');
  if (!badgeRows.length) return [];

  const valuesRow = await queryOne(ctx.env, `
    SELECT
      COALESCE((SELECT xp_total FROM student_stats WHERE student_id=?), 0) AS xp_total,
      COALESCE((SELECT level FROM student_stats WHERE student_id=?), 0) AS level,
      (SELECT COUNT(*) FROM material_progress_events WHERE student_id=?) AS progress_events,
      (SELECT COUNT(*) FROM material_progress WHERE student_id=? AND progress_percent>=100) AS completed_materials
  `, studentId, studentId, studentId, studentId);
  const xpTotal = Number(valuesRow?.xp_total || 0);
  const values = {
    xp_total: xpTotal,
    level: Number(valuesRow?.level || calculateLevel(xpTotal)),
    progress_events: Number(valuesRow?.progress_events || 0),
    completed_materials: Number(valuesRow?.completed_materials || 0),
  };

  const eligible = badgeRows.filter((badge) => {
    const current = Number(values[badge.rule_type] || 0);
    const threshold = Number(badge.rule_value || 0);
    return threshold > 0 && current >= threshold;
  });
  if (!eligible.length) return [];

  const results = await ctx.env.DB.batch(
    eligible.map((badge) => ctx.env.DB.prepare(
      'INSERT INTO student_badges(student_id,badge_id) VALUES(?,?) ON CONFLICT(student_id,badge_id) DO NOTHING'
    ).bind(studentId, badge.id))
  );
  return eligible.filter((_, index) => Number(results[index]?.meta?.changes || 0) > 0).map((badge) => badge.id);
}
