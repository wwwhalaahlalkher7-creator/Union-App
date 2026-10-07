import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE, XP_MATERIAL_PAGE, XP_MATERIAL_COMPLETION, MATERIAL_MIN_ACTIVE_SECONDS,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { studentAuth } from './auth.js';
import { badgeRows, badgeCategoryRows } from './badges_catalog.js';
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
  const aggregate = await queryOne(ctx.env, 'SELECT COALESCE(SUM(xp), 0) AS xp_total FROM xp_events WHERE student_id = ?', a.session.student_id);
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
  });
}

export async function badges(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;

  // Badge definitions are application-owned. The endpoint intentionally derives
  // eligibility from the normal student activity tables instead of reading or
  // writing the legacy dashboard-managed `badges` / `student_badges` tables.
  // This keeps badges available even when an older production database has not
  // received the optional badge migrations yet.
  let metrics = null;
  try {
    metrics = await queryOne(ctx.env, `
    SELECT
      (SELECT COALESCE(SUM(xp),0) FROM xp_events WHERE student_id=?) AS xp_total,
      (SELECT COUNT(*) FROM material_progress WHERE student_id=?) AS progress_events,
      (SELECT COUNT(*) FROM material_progress WHERE student_id=? AND progress_percent>=100) AS completed_materials,
      (SELECT COUNT(DISTINCT m.subject_id)
         FROM material_progress mp
         JOIN materials m ON m.id=mp.material_id
        WHERE mp.student_id=? AND mp.progress_percent>=100) AS completed_subjects,
      (SELECT COUNT(*) FROM xp_events WHERE student_id=? AND event_type='learning_event_complete') AS learning_events,
      (SELECT COUNT(*) FROM comments WHERE student_id=? AND status='visible') AS comments,
      (SELECT COUNT(*) FROM reactions WHERE student_id=?) AS reactions,
      (SELECT COUNT(*) FROM comment_replies WHERE student_id=? AND status='visible') AS replies
  `,
    a.session.student_id,
    a.session.student_id,
    a.session.student_id,
    a.session.student_id,
    a.session.student_id,
    a.session.student_id,
    a.session.student_id,
    a.session.student_id,
  );
  } catch (e) {
    // Badge rendering must never take down the XP page. If a legacy/partially
    // migrated database is missing one of the activity tables, return the fixed
    // catalogue with zero earned metrics; the next successful request will
    // recompute the real state.
    console.error(`[${ctx.requestId}] badge metrics unavailable`, e);
  }

  const xpTotal = Number(metrics?.xp_total || 0);
  const values = {
    xp_total: xpTotal,
    level: calculateLevel(xpTotal),
    progress_events: Number(metrics?.progress_events || 0),
    completed_materials: Number(metrics?.completed_materials || 0),
    completed_subjects: Number(metrics?.completed_subjects || 0),
    learning_events: Number(metrics?.learning_events || 0),
    comments: Number(metrics?.comments || 0),
    reactions: Number(metrics?.reactions || 0),
    replies: Number(metrics?.replies || 0),
  };

  const definitions = badgeRows(xpTotal);
  const rows = definitions.map((badge) => {
    const current = Number(values[badge.rule_type] || 0);
    const earned = Number(badge.rule_value || 0) > 0 && current >= Number(badge.rule_value);
    return { ...badge, earned, awarded_at: null };
  }).filter((badge) => badge.earned);

  const categories = badgeCategoryRows(values);
  return ok(ctx, {
    badges: rows,
    categories,
    earnedCount: rows.length,
    totalCount: rows.length + categories.filter(c => c.next).length,
    newlyAwarded: [],
  });
}

export async function materialProgress(ctx, materialId) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request) || {};
  const eventType = String(body.eventType || 'progress').trim().toLowerCase();
  const requestedPercent = Number.parseInt(body.progressPercent, 10);
  const requestedPage = Number.parseInt(body.pageNumber, 10);
  const requestedPageCount = Number.parseInt(body.pageCount, 10);
  const pageNumber = Number.isFinite(requestedPage) ? Math.max(0, requestedPage) : 0;
  const pageCount = Number.isFinite(requestedPageCount) ? Math.min(100000, Math.max(0, requestedPageCount)) : 0;
  const percent = Number.isFinite(requestedPercent) ? Math.min(100, Math.max(0, requestedPercent)) : 0;
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

  const previousPercent = Math.min(100, Math.max(0, Number(existing?.progress_percent || 0)));
  const previousPage = Math.max(0, Number(existing?.last_page_number || 0));
  const effectivePageCount = pageCount || Math.max(0, Number(existing?.page_count || 0));
  let nextPercent = previousPercent;
  let nextPage = previousPage;

  if (eventType !== 'open') {
    nextPage = Math.max(previousPage, Math.min(pageNumber, effectivePageCount || pageNumber));
    const calculatedPercent = effectivePageCount > 0
      ? Math.min(100, Math.floor((nextPage / effectivePageCount) * 100))
      : percent;
    nextPercent = Math.max(previousPercent, calculatedPercent);

  }

  const activeSeconds = Math.min((existing?.active_seconds || 0) + boundedElapsed, 8 * 60 * 60);
  const completed = nextPercent >= 100;
  const shouldRecordProgress = eventType === 'open' || nextPercent > previousPercent || nextPage > previousPage || activeSeconds !== (existing?.active_seconds || 0);

  if (existing) {
    if (shouldRecordProgress) {
      await ctx.env.DB.prepare(`UPDATE material_progress SET progress_percent = ?, active_seconds = ?, last_page_number = ?, page_count = ?, last_opened_at = CURRENT_TIMESTAMP,
        last_progress_at = CASE WHEN ? = 1 THEN CURRENT_TIMESTAMP ELSE last_progress_at END,
        completed_at = CASE WHEN ? = 1 THEN COALESCE(completed_at, CURRENT_TIMESTAMP) ELSE completed_at END
        WHERE student_id = ? AND material_id = ?`)
        .bind(nextPercent, activeSeconds, nextPage, effectivePageCount, eventType === 'open' ? 0 : (nextPercent > previousPercent || nextPage > previousPage) ? 1 : 0, completed ? 1 : 0, a.session.student_id, materialId).run();
    }
  } else {
    await ctx.env.DB.prepare(`INSERT INTO material_progress
      (id, student_id, material_id, progress_percent, first_opened_at, last_opened_at, completed_at, active_seconds, last_progress_at, last_page_number, page_count)
      VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?)`)
      .bind(crypto.randomUUID(), a.session.student_id, materialId, nextPercent, completed ? new Date().toISOString() : null, activeSeconds,
        eventType === 'open' ? null : new Date().toISOString(), nextPage, effectivePageCount).run();
  }

  await ctx.env.DB.prepare(`INSERT INTO material_progress_events
    (id, student_id, material_id, event_type, progress_percent, active_seconds)
    VALUES (?, ?, ?, ?, ?, ?)`)
    .bind(crypto.randomUUID(), a.session.student_id, materialId, eventType, nextPercent, boundedElapsed).run();

  const xpAwarded = nextPercent > previousPercent || nextPage > previousPage
    ? await awardProgressXp(ctx, a.session.student_id, materialId, previousPage, nextPage, completed, activeSeconds)
    : 0;
  const newlyAwardedBadges = await evaluateBadges(ctx, a.session.student_id);
  return ok(ctx, {
    materialId,
    progressPercent: nextPercent,
    completed,
    activeSeconds,
    pageNumber: nextPage,
    pageCount: effectivePageCount,
    accepted: true,
    xpAwarded,
    newlyAwardedBadges,
    minActiveSeconds: MATERIAL_MIN_ACTIVE_SECONDS,
  });
}

export function calculateLevel(totalXp) {
  const safe = Math.max(0, Number(totalXp) || 0);
  return Math.floor(safe / XP_LEVEL_BASE) + 1;
}

export async function awardProgressXp(ctx, studentId, materialId, previousPage, nextPage, completed, activeSeconds) {
  if (activeSeconds < MATERIAL_MIN_ACTIVE_SECONDS || nextPage <= previousPage) return 0;

  const currentPage = Math.min(100000, Math.max(0, Number(nextPage) || 0));
  const previous = Math.min(currentPage, Math.max(0, Number(previousPage) || 0));
  const newPage = currentPage > 0 && currentPage !== previous ? currentPage : (currentPage > 0 ? currentPage : 0);
  const pages = newPage > 0 ? [newPage] : [];

  const statements = pages.map((page) => ctx.env.DB.prepare(`
    INSERT INTO xp_events (id, student_id, event_type, source_id, xp)
    SELECT ?, ?, ?, ?, ?
    WHERE (SELECT COALESCE(SUM(xp),0) FROM xp_events WHERE student_id=? AND created_at >= date('now')) + ? <= ?
    ON CONFLICT(student_id, event_type, source_id) DO NOTHING
  `).bind(
    crypto.randomUUID(), studentId, 'material_page', `${materialId}:page:${page}`, XP_MATERIAL_PAGE,
    studentId, XP_MATERIAL_PAGE, XP_DAILY_CAP,
  ));

  if (completed) {
    statements.push(ctx.env.DB.prepare(`
      INSERT INTO xp_events (id, student_id, event_type, source_id, xp)
      SELECT ?, ?, ?, ?, ?
      WHERE (SELECT COALESCE(SUM(xp),0) FROM xp_events WHERE student_id=? AND created_at >= date('now')) + ? <= ?
      ON CONFLICT(student_id, event_type, source_id) DO NOTHING
    `).bind(
      crypto.randomUUID(), studentId, 'material_complete', materialId, XP_MATERIAL_COMPLETION,
      studentId, XP_MATERIAL_COMPLETION, XP_DAILY_CAP,
    ));
  }
  if (!statements.length) return 0;

  const results = await ctx.env.DB.batch(statements);
  const pageAwarded = pages.length > 0 && Number(results[0]?.meta?.changes || 0) > 0;
  const completionIndex = pages.length;
  const completionAwarded = completed && Number(results[completionIndex]?.meta?.changes || 0) > 0 ? XP_MATERIAL_COMPLETION : 0;
  if (!pageAwarded && completionAwarded <= 0) return 0;
  const xpAwarded = (pageAwarded ? XP_MATERIAL_PAGE : 0) + completionAwarded;

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
  return xpAwarded;
}

export async function evaluateBadges(ctx, studentId) {
  // Badge definitions are immutable application code. Persistence here is only
  // the student's earned state; there is no admin CRUD or dashboard control.
  const definitions = badgeRows(0);
  if (!definitions.length) return [];

  const valuesRow = await queryOne(ctx.env, `
    SELECT
      COALESCE((SELECT SUM(xp) FROM xp_events WHERE student_id=?),0) AS xp_total,
      COALESCE((SELECT level FROM student_stats WHERE student_id=?),0) AS level,
      (SELECT COUNT(*) FROM material_progress_events WHERE student_id=?) AS progress_events,
      (SELECT COUNT(*) FROM material_progress WHERE student_id=? AND progress_percent>=100) AS completed_materials,
      (SELECT COUNT(DISTINCT m.subject_id) FROM material_progress mp JOIN materials m ON m.id=mp.material_id WHERE mp.student_id=? AND mp.progress_percent>=100 AND m.subject_id IS NOT NULL) AS completed_subjects,
      (SELECT COUNT(*) FROM xp_events WHERE student_id=? AND event_type='learning_event_complete') AS learning_events,
      (SELECT COUNT(*) FROM comments WHERE student_id=? AND status='visible') AS comments,
      (SELECT COUNT(*) FROM reactions WHERE student_id=?) AS reactions,
      (SELECT COUNT(*) FROM comment_replies WHERE student_id=? AND status='visible') AS replies
  `, studentId, studentId, studentId, studentId, studentId, studentId, studentId, studentId, studentId);

  const xpTotal = Number(valuesRow?.xp_total || 0);
  const values = {
    xp_total: xpTotal,
    level: Number(valuesRow?.level || calculateLevel(xpTotal)),
    progress_events: Number(valuesRow?.progress_events || 0),
    completed_materials: Number(valuesRow?.completed_materials || 0),
    completed_subjects: Number(valuesRow?.completed_subjects || 0),
    learning_events: Number(valuesRow?.learning_events || 0),
    comments: Number(valuesRow?.comments || 0),
    reactions: Number(valuesRow?.reactions || 0),
    replies: Number(valuesRow?.replies || 0),
  };

  const eligibleDefinitions = badgeRows(xpTotal);
  const eligible = eligibleDefinitions.filter((badge) => {
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
