import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { auth } from './auth.js';
export function publicVersion(ctx) {
  const appVersion = ctx.env.APP_VERSION || 'unknown';
  const minimumAppVersion = ctx.env.MINIMUM_APP_VERSION || null;
  return ok(ctx, {
    name: 'TRINEX',
    appVersion,
    minimumAppVersion,
    updateUrl: ctx.env.APP_UPDATE_URL || null,
    releaseNotes: ctx.env.APP_RELEASE_NOTES || null,
    apiVersion: ctx.env.API_VERSION || 'v1',
  });
}

export function appUpdate(ctx) {
  const latestVersion = String(ctx.env.APP_VERSION || '').trim();
  if (!latestVersion || latestVersion === 'unknown') {
    return error('UPDATE_MANIFEST_UNAVAILABLE', 'بيانات التحديث غير مهيأة حاليًا.', 503, ctx.requestId, ctx.cors);
  }

  return ok(ctx, {
    latestVersion,
    minimumVersion: ctx.env.MINIMUM_APP_VERSION || null,
    downloadUrl: ctx.env.APP_UPDATE_URL || null,
    releaseNotes: ctx.env.APP_RELEASE_NOTES || null,
    apiVersion: ctx.env.API_VERSION || 'v1',
  });
}

export async function health(ctx) {
  let db = 'unavailable';
  try { await queryOne(ctx.env, 'SELECT 1 AS ok'); db = 'ok'; } catch (_) {}
  return ok(ctx, { service: 'association-api', apiVersion: ctx.env.API_VERSION || 'v1', appVersion: ctx.env.APP_VERSION || 'unknown', database: db, timestamp: new Date().toISOString() });
}

export async function publicContentDetail(ctx) {
  const parts = ctx.path.split('/');
  const table = parts[2];
  const id = parts[3];
  if (!['news', 'events', 'achievements'].includes(table) || !id) {
    return error('CONTENT_NOT_FOUND','المحتوى غير موجود.',404,ctx.requestId,ctx.cors);
  }

  const dateColumn = table === 'events' ? 'event_at' : table === 'achievements' ? 'achieved_at' : 'publish_at';
  const expiryClause = table === 'news'
    ? " AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)"
    : '';

  let studentId = null;
  const optionalAuth = await auth(ctx, false);
  if (optionalAuth?.session?.student_id && !optionalAuth.session.staff_user_id) {
    studentId = optionalAuth.session.student_id;
  }

  const type = table === 'news' ? 'news' : table === 'events' ? 'event' : 'achievement';
  const myReactionSql = studentId
    ? `(SELECT r2.reaction FROM reactions r2 WHERE r2.content_type=? AND r2.content_id=${table}.id AND r2.student_id=?) AS my_reaction`
    : 'NULL AS my_reaction';

  const params = [type, type];
  if (studentId) params.push(type, studentId);
  params.push(id);

  const row = await queryOne(
    ctx.env,
    `SELECT ${table}.*,
      (SELECT COUNT(*) FROM comments c WHERE c.content_type=? AND c.content_id=${table}.id AND c.status='visible') AS comment_count,
      (SELECT COUNT(*) FROM reactions r WHERE r.content_type=? AND r.content_id=${table}.id) AS like_count,
      ${myReactionSql}
    FROM ${table}
    WHERE id=? AND status='published'
      AND (${dateColumn} IS NULL OR ${dateColumn} <= CURRENT_TIMESTAMP)
      ${expiryClause}`,
    ...params,
  );

  if (!row) return error('CONTENT_NOT_FOUND','المحتوى غير موجود أو غير متاح حاليًا.',404,ctx.requestId,ctx.cors);
  if (table === 'achievements') {
    return ok(ctx, {
      id: row.id, title: row.title, description: row.description || null,
      intro: row.intro || row.description || null, highlightsTitle: row.highlights_title || null,
      highlights: parseJsonValue(row.highlights, null), badge: row.badge || null,
      publisher: row.publisher || null, imageUrl: row.image_url || null,
      images: parseJsonValue(row.images_json, []), achievedAt: row.achieved_at || null,
      createdAt: row.created_at || null, updatedAt: row.updated_at || null,
      commentCount: Number(row.comment_count || 0), likeCount: Number(row.like_count || 0),
      myReaction: row.my_reaction || null,
    }, {source:'d1'});
  }
  return ok(ctx, serializePublicContent(table, row), {source:'d1'});
}

export function serializePublicContent(table, row) {
  const images = parseJsonValue(row.images_json, []);
  const normalizedImages = Array.isArray(images) ? images.map(v => typeof v === 'string' ? v : (v?.url || '')).filter(Boolean) : [];
  if (row.image_url && !normalizedImages.includes(row.image_url)) normalizedImages.unshift(row.image_url);
  const common = { id: row.id, title: row.title, body: row.body || null, imageUrl: normalizedImages[0] || null, images: normalizedImages, category: row.category || null, publisher: row.publisher || null, createdAt: row.created_at || null, updatedAt: row.updated_at || null, commentCount: Number(row.comment_count || 0), likeCount: Number(row.like_count || 0), myReaction: row.my_reaction || null };
  if (['events'].includes(table)) Object.assign(common, {eventAt: row.event_at || null, endAt: row.end_at || null, location: row.location || null});
  else Object.assign(common, {publishAt: row.publish_at || null, expiresAt: row.expires_at || null});
  return common;
}

export async function publicList(ctx, table) {
  const limit = clampInt(ctx.url.searchParams.get('limit'), 20);
  const dateColumn = ['events'].includes(table) ? 'event_at' : table === 'achievements' ? 'achieved_at' : 'publish_at';
  const order = `${dateColumn} DESC`;
  const expiryClause = ['news', 'announcements'].includes(table)
    ? " AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)"
    : '';

  // Public content remains readable without authentication. When a valid
  // student session is present, also return that student's reaction state so
  // the UI can survive refresh/navigation without losing the like state.
  let studentId = null;
  const optionalAuth = await auth(ctx, false);
  if (optionalAuth?.session?.student_id && !optionalAuth.session.staff_user_id) {
    studentId = optionalAuth.session.student_id;
  }

  const type = table === 'news'
    ? 'news'
    : table === 'announcements'
      ? 'announcement'
      : table === 'events'
        ? 'event'
        : 'achievement';

  const myReactionSql = studentId
    ? `(SELECT r2.reaction FROM reactions r2 WHERE r2.content_type = ? AND r2.content_id = ${table}.id AND r2.student_id = ?) AS my_reaction`
    : 'NULL AS my_reaction';

  const sql = `SELECT ${table}.*,
       (SELECT COUNT(*) FROM comments c WHERE c.content_type = ? AND c.content_id = ${table}.id AND c.status = 'visible') AS comment_count,
       (SELECT COUNT(*) FROM reactions r WHERE r.content_type = ? AND r.content_id = ${table}.id) AS like_count,
       ${myReactionSql}
     FROM ${table}
     WHERE status = 'published'
       AND (${dateColumn} IS NULL OR ${dateColumn} <= CURRENT_TIMESTAMP)
       ${expiryClause}
     ORDER BY ${order} LIMIT ?`;

  const params = [type, type];
  if (studentId) params.push(type, studentId);
  params.push(limit);

  const rows = await queryAll(ctx.env, sql, ...params);

  const data = rows.map(row => {
    if (table === 'news' || table === 'events') {
      return serializePublicContent(table, row);
    }
    if (table === 'achievements') return {
      id: row.id,
      title: row.title,
      description: row.description || null,
      intro: row.intro || row.description || null,
      highlightsTitle: row.highlights_title || null,
      highlights: parseJsonValue(row.highlights, null),
      badge: row.badge || null,
      publisher: row.publisher || null,
      imageUrl: row.image_url || null,
      images: parseJsonValue(row.images_json, null),
      achievedAt: row.achieved_at || null,
      createdAt: row.created_at || null,
      updatedAt: row.updated_at || null,
      commentCount: Number(row.comment_count || 0),
      likeCount: Number(row.like_count || 0),
      myReaction: row.my_reaction || null,
    };
    return {
      id: row.id,
      title: row.title,
      body: row.body,
      type: row.type || 'general',
      targetDepartmentId: row.target_department_id || null,
      targetSemesterId: row.target_semester_id || null,
      publishAt: row.publish_at || null,
      expiresAt: row.expires_at || null,
      createdAt: row.created_at || null,
      updatedAt: row.updated_at || null,
    };
  });

  return ok(ctx, data, { source: 'd1', count: data.length, limit });
}

export async function publicMaterials(ctx) {
  const departmentId = String(ctx.url.searchParams.get('departmentId') || '').trim() || null;
  const semesterId = String(ctx.url.searchParams.get('semesterId') || '').trim() || null;
  const subjectId = String(ctx.url.searchParams.get('subjectId') || '').trim() || null;
  const limit = clampInt(ctx.url.searchParams.get('limit'), 1000, 1, 1000);

  const rows = await queryAll(ctx.env, `
    SELECT
      m.id, m.subject_id, m.title, m.description, m.drive_file_id,
      m.drive_url, m.drive_web_view_url, m.mime_type, m.size_bytes,
      m.active, m.sort_order, m.created_at, m.updated_at,
      m.pinned, m.source, m.drive_modified_at,
      s.code AS subject_code, s.name_ar AS subject_name, s.name_en AS subject_name_en,
      s.semester_id, s.department_id, s.sort_order AS subject_sort_order,
      sem.name_ar AS semester_name_ar, sem.name_en AS semester_name_en,
      sem.number AS semester_number,
      d.name_ar AS department_name_ar, d.name_en AS department_name_en,
      d.code AS department_code, d.sort_order AS department_sort_order
    FROM materials m
    JOIN subjects s ON s.id = m.subject_id
    JOIN departments d ON d.id = s.department_id
    JOIN semesters sem ON sem.id = s.semester_id
    WHERE m.active = 1 AND s.active = 1 AND d.active = 1 AND sem.active = 1
      AND (? IS NULL OR d.id = ?)
      AND (? IS NULL OR sem.id = ?)
      AND (? IS NULL OR s.id = ?)
    ORDER BY
      d.sort_order, d.name_ar,
      sem.number, sem.name_ar,
      s.sort_order, s.name_ar,
      m.pinned DESC, m.sort_order,
      COALESCE(m.drive_modified_at, m.updated_at, m.created_at) DESC,
      m.title
    LIMIT ?`,
    departmentId, departmentId,
    semesterId, semesterId,
    subjectId, subjectId,
    limit
  );

  const departments = [];
  const departmentMap = new Map();
  const semesterMap = new Map();
  const subjectMap = new Map();

  for (const row of rows) {
    let department = departmentMap.get(row.department_id);
    if (!department) {
      department = {
        id: row.department_id,
        name: row.department_name_ar || row.department_name_en || row.department_code || '',
        nameEn: row.department_name_en || null,
        code: row.department_code || null,
        semesters: [],
      };
      departmentMap.set(row.department_id, department);
      departments.push(department);
    }

    const semesterKey = `${row.department_id}:${row.semester_id}`;
    let semester = semesterMap.get(semesterKey);
    if (!semester) {
      semester = {
        id: row.semester_id,
        name: row.semester_name_ar || row.semester_name_en || `الفصل ${row.semester_number}`,
        nameEn: row.semester_name_en || null,
        number: Number(row.semester_number || 0),
        subjects: [],
      };
      semesterMap.set(semesterKey, semester);
      department.semesters.push(semester);
    }

    const subjectKey = `${row.department_id}:${row.semester_id}:${row.subject_id}`;
    let subject = subjectMap.get(subjectKey);
    if (!subject) {
      subject = {
        id: row.subject_id,
        code: row.subject_code || null,
        name: row.subject_name || row.subject_name_en || row.subject_code || '',
        nameEn: row.subject_name_en || null,
        files: [],
      };
      subjectMap.set(subjectKey, subject);
      semester.subjects.push(subject);
    }

    const driveId = row.drive_file_id || null;
    const viewUrl = row.drive_web_view_url || row.drive_url || null;
    subject.files.push({
      id: row.id,
      name: row.title,
      mimeType: row.mime_type || 'application/pdf',
      sizeBytes: Number(row.size_bytes || 0),
      viewUrl,
      downloadUrl: driveId
        ? `https://drive.google.com/uc?export=download&id=${encodeURIComponent(driveId)}`
        : viewUrl,
      modifiedAt: row.drive_modified_at || row.updated_at || row.created_at || null,
    });
  }

  for (const department of departments) {
    department.semesters.sort((a, b) => a.number - b.number || a.name.localeCompare(b.name, 'ar'));
    for (const semester of department.semesters) {
      semester.subjects.sort((a, b) => a.name.localeCompare(b.name, 'ar'));
    }
  }
  departments.sort((a, b) => a.name.localeCompare(b.name, 'ar'));

  return ok(ctx, {
    departments,
  }, {
    source: 'd1',
    count: rows.length,
    limit,
    departmentId,
    semesterId,
    subjectId,
  });
}

export async function publicSettings(ctx) {
  const rows = await queryAll(ctx.env, "SELECT key, value_json FROM app_settings WHERE key LIKE 'public.%' ORDER BY key");
  const data = {};
  for (const row of rows) { try { data[row.key.replace(/^public\./, '')] = JSON.parse(row.value_json); } catch { data[row.key.replace(/^public\./, '')] = row.value_json; } }
  return ok(ctx, data);
}
