import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { staffAuth } from './auth.js';
import { materials, subjects } from './academic.js';
import { createOrRefreshContentNotificationDraft } from './notification_drafts.js';
export async function adminDriveAuth(ctx) {
  const a = await staffAuth(ctx);
  if (a.response) return a.response;
  if (!a.session.staff_user_id || a.session.staff_active !== 1) return error('STAFF_AUTH_REQUIRED', 'جلسة موظف الإدارة مطلوبة.', 403, ctx.requestId, ctx.cors);
  const role = a.session.staff_role_id;
  if (!['super_admin', 'academic_manager'].includes(role)) return error('FORBIDDEN', 'صلاحية إدارة المواد الأكاديمية مطلوبة.', 403, ctx.requestId, ctx.cors);
  return a;
}

export function normalizeDriveName(name) {
  return String(name || '')
    .trim()
    .replace(/[ًٌٍَُِّْـ]/g, '')
    .replace(/[إأآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

export function departmentAliases(department) {
  const aliases = [department?.name_ar, department?.name_en, department?.code];
  const code = normalizeDriveName(department?.code);
  if (code === 'ee') aliases.push('الهندسة الكهربائية الإلكترونية', 'الهندسة الكهربائية والالكترونية', 'كهرباء إلكترونية', 'كهرباء الكترونية');
  if (code === 'ce') aliases.push('الهندسة المدنية', 'مدنية');
  if (code === 'arch') aliases.push('هندسة العمارة', 'الهندسة المعمارية', 'معمار');
  return aliases.filter(Boolean);
}

export function semesterNumberFromName(name) {
  const value = normalizeDriveName(name);
  const arabic = {
    'الاول': 1, 'الأول': 1, 'اول': 1,
    'الثاني': 2, 'الثانى': 2, 'ثاني': 2,
    'الثالث': 3, 'ثالث': 3, 'الرابع': 4, 'رابع': 4,
    'الخامس': 5, 'خامس': 5, 'السادس': 6, 'سادس': 6,
    'السابع': 7, 'سابع': 7, 'الثامن': 8, 'ثامن': 8,
    'التاسع': 9, 'تاسع': 9, 'العاشر': 10, 'عاشر': 10,
  };
  for (const [word, number] of Object.entries(arabic)) {
    if (value.includes(word)) return number;
  }
  const match = value.match(/(?:semester|الفصل|سمستر|السمستر)\s*[-_#:]?\s*(\d{1,2})/i);
  return match ? Number(match[1]) : null;
}

export function drivePin(description) {
  const value = String(description || '').toLowerCase();
  return ['pinned', 'مثبت', 'مثبّت'].some(k => value.includes(k));
}

export async function fetchAppsScriptIndex(ctx, forceRefresh = false) {
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  const token = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN || '').trim();
  if (!endpoint || !token) throw new Error('TRINEX Drive adapter is not configured.');
  let url;
  try { url = new URL(endpoint); } catch (e) { throw new Error('GOOGLE_APPS_SCRIPT_DRIVE_URL غير صالح.'); }
  url.searchParams.set('action', 'index');
  url.searchParams.set('token', token);
  if (forceRefresh) url.searchParams.set('nocache', '1');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: { accept: 'application/json' },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Apps Script index failed (${response.status}).`);
    const data = await response.json();
    if (!data || data.success !== true || !Array.isArray(data.files)) {
      throw new Error(String(data?.error || 'Apps Script returned an invalid index.'));
    }
    return data;
  } finally {
    clearTimeout(timeout);
  }
}

export async function deleteDriveFilesViaAppsScript(ctx, fileIds) {
  const uniqueIds = [...new Set((Array.isArray(fileIds) ? fileIds : []).map(v => String(v || '').trim()).filter(Boolean))];
  if (!uniqueIds.length) return { deleted: [], count: 0 };
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  const token = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN || '').trim();
  if (!endpoint || !token) throw new Error('TRINEX Drive adapter is not configured.');
  let url;
  try { url = new URL(endpoint); } catch (e) { throw new Error('GOOGLE_APPS_SCRIPT_DRIVE_URL غير صالح.'); }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(url.toString(), {
      method: 'POST',
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ action: 'deleteFiles', token, fileIds: uniqueIds }),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Apps Script delete failed (${response.status}).`);
    const data = await response.json();
    if (!data || data.success !== true || Number(data.failedCount || 0) > 0) {
      throw new Error(String(data?.error || `فشل حذف ${Number(data?.failedCount || 0)} ملف من Google Drive.`));
    }
    return data;
  } finally { clearTimeout(timeout); }
}


async function appsScriptPost(ctx, payload, timeoutMs = 30000) {
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  const token = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN || '').trim();
  if (!endpoint || !token) throw new Error('TRINEX Drive adapter is not configured.');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ ...payload, token }),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Apps Script request failed (${response.status}).`);
    const data = await response.json();
    if (!data || data.success !== true) throw new Error(String(data?.error || 'Apps Script operation failed.'));
    return data;
  } finally { clearTimeout(timeout); }
}

export async function ensureDriveSubjectFolder(ctx, { departmentName, semesterName, subjectName }) {
  return appsScriptPost(ctx, { action: 'ensureSubjectFolder', departmentName, semesterName, subjectName });
}

export async function uploadDrivePdf(ctx, { folderId, fileName, base64 }) {
  if (!folderId || !fileName || !base64) throw new Error('بيانات ملف PDF غير مكتملة.');
  return appsScriptPost(ctx, { action: 'uploadPdf', folderId, fileName, base64 }, 60000);
}

export async function deleteDriveFolderViaAppsScript(ctx, folderId) {
  if (!folderId) return { success: true, deleted: false };
  return appsScriptPost(ctx, { action: 'deleteFolder', folderId }, 30000);
}

export async function adminUploadMaterialPdf(ctx) {
  const a = await adminDriveAuth(ctx); if (a.response) return a.response;
  let body;
  try { body = await ctx.request.json(); } catch (_) {
    return error('INVALID_JSON', 'بيانات رفع الملف غير صالحة.', 400, ctx.requestId, ctx.cors);
  }
  const subjectId = String(body?.subjectId || '').trim();
  const title = String(body?.title || '').trim();
  const fileName = String(body?.fileName || '').trim();
  const base64 = String(body?.base64 || '').replace(/^data:application\/pdf;base64,/, '');
  if (!subjectId || !title || !fileName || !base64) return error('MATERIAL_INPUT_INVALID', 'اختر المادة والعنوان وملف PDF.', 400, ctx.requestId, ctx.cors);
  if (!/\.pdf$/i.test(fileName)) return error('PDF_REQUIRED', 'يسمح برفع ملفات PDF فقط.', 400, ctx.requestId, ctx.cors);
  if (base64.length > 12 * 1024 * 1024) return error('PDF_TOO_LARGE', 'حجم الملف أكبر من الحد المسموح (نحو 9 ميجابايت).', 413, ctx.requestId, ctx.cors);
  const subject = await queryOne(ctx.env, `SELECT s.*, d.name_ar AS department_name, sem.name_ar AS semester_name
    FROM subjects s JOIN departments d ON d.id=s.department_id JOIN semesters sem ON sem.id=s.semester_id
    WHERE s.id=? AND s.active=1`, subjectId);
  if (!subject) return error('SUBJECT_NOT_FOUND', 'المادة غير موجودة أو غير نشطة.', 404, ctx.requestId, ctx.cors);
  let folder = await queryOne(ctx.env, `SELECT id,parent_id FROM drive_folder_index WHERE subject_id=? AND folder_type='subject' AND active=1 ORDER BY last_synced_at DESC LIMIT 1`, subjectId);
  if (folder && (/^(drive-folder-|apps-script-)/.test(String(folder.id)))) folder = null;
  let uploadedFileId = null;
  try {
    if (!folder) {
      const made = await ensureDriveSubjectFolder(ctx, { departmentName: subject.department_name, semesterName: subject.semester_name, subjectName: subject.name_ar });
      folder = { id: made.folderId, parent_id: made.semesterFolderId || null };
      await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,subject_id,name,active,last_synced_at)
        VALUES (?,?,?,?,?,?,?,1,CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,department_id=excluded.department_id,semester_id=excluded.semester_id,subject_id=excluded.subject_id,name=excluded.name,active=1,last_synced_at=CURRENT_TIMESTAMP`)
        .bind(folder.id, folder.parent_id, 'subject', subject.department_id, subject.semester_id, subject.id, subject.name_ar).run();
    }
    const uploaded = await uploadDrivePdf(ctx, { folderId: folder.id, fileName, base64 });
    uploadedFileId = uploaded.fileId;
    const id = `drive-material-${uploaded.fileId}`;
    const link = uploaded.webViewUrl || `https://drive.google.com/file/d/${uploaded.fileId}/view`;
    await ctx.env.DB.prepare(`INSERT INTO materials
      (id,subject_id,title,description,drive_file_id,drive_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_web_view_url,pinned,source,last_synced_at)
      VALUES (?,?,?,?,?,?,?, ?,1,0,?,?,0,'drive',CURRENT_TIMESTAMP)`)
      .bind(id, subjectId, title, String(body.description || '').trim() || null, uploaded.fileId, link, 'application/pdf', Number(uploaded.sizeBytes || 0), folder.id, link).run();
    const created = await queryOne(ctx.env, 'SELECT * FROM materials WHERE id=?', id);
    await createOrRefreshContentNotificationDraft(ctx, 'materials', created, a.session.staff_user_id);
    return ok(ctx, created, null, 201);
  } catch (e) {
    if (uploadedFileId) {
      try { await deleteDriveFilesViaAppsScript(ctx, [uploadedFileId]); } catch (cleanupError) {
        console.error(`[${ctx.requestId}] orphan PDF cleanup failed`, cleanupError);
      }
    }
    console.error(`[${ctx.requestId}] direct PDF upload failed`, e);
    return error('DRIVE_UPLOAD_FAILED', 'تعذر رفع ملف PDF إلى Google Drive؛ لم تتم إضافة سجل الشيت.', 502, ctx.requestId, ctx.cors, String(e?.message || e));
  }
}

export async function adminDriveSync(ctx) {
  const a = await adminDriveAuth(ctx); if (a.response) return a.response;
  const syncId = crypto.randomUUID();
  const configuredUrl = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  if (!configuredUrl) return error('DRIVE_NOT_CONFIGURED', 'رابط Google Apps Script غير مهيأ.', 503, ctx.requestId, ctx.cors);
  await ctx.env.DB.prepare('INSERT INTO drive_sync_runs (id, root_folder_id, status, triggered_by) VALUES (?, ?, ?, ?)')
    .bind(syncId, 'apps-script', 'running', a.session.staff_user_id).run();

  try {
    const index = await fetchAppsScriptIndex(ctx, ctx.url.searchParams.get('nocache') === '1');
    const departments = await queryAll(ctx.env, 'SELECT * FROM departments WHERE active = 1');
    const semesters = await queryAll(ctx.env, 'SELECT * FROM semesters WHERE active = 1');
    const depByName = new Map();
    const semByName = new Map();
    for (const d of departments) for (const n of departmentAliases(d)) depByName.set(normalizeDriveName(n), d);
    for (const s of semesters) for (const n of [s.name_ar, s.name_en, `semester ${s.number}`, `الفصل ${s.number}`, `سمستر ${s.number}`, `السمستر ${s.number}`]) if (n) semByName.set(normalizeDriveName(n), s);

    let foldersSeen = Array.isArray(index.sections) ? index.sections.reduce((n, s) => n + 1 + (Array.isArray(s.semesters) ? s.semesters.length : 0), 0) : 0;
    let filesSeen = index.files.length;
    let upserted = 0;

    // Keep the folder index coherent with the Apps Script source.
    for (const section of (Array.isArray(index.sections) ? index.sections : [])) {
      const dep = depByName.get(normalizeDriveName(section.name));
      if (!dep) continue;
      const depIndexId = `apps-script-department-${section.id}`;
      await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,name,modified_at,active,last_synced_at)
        VALUES (?,?,?,?,?,?,1,CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
        .bind(depIndexId, 'apps-script-root', 'department', dep.id, section.name, null).run();
      for (const semester of (Array.isArray(section.semesters) ? section.semesters : [])) {
        const sem = semByName.get(normalizeDriveName(semester.name)) || semesters.find(s => s.number === semesterNumberFromName(semester.name));
        if (!sem) continue;
        const semIndexId = `apps-script-semester-${semester.id}`;
        await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,name,modified_at,active,last_synced_at)
          VALUES (?,?,?,?,?,?,?,1,CURRENT_TIMESTAMP)
          ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,semester_id=excluded.semester_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
          .bind(semIndexId, depIndexId, 'semester', dep.id, sem.id, semester.name, null).run();
      }
    }

    // Group the flat Apps Script file index by department + semester + material.
    const subjectGroups = new Map();
    for (const file of index.files) {
      const dep = depByName.get(normalizeDriveName(file.sectionName));
      const sem = semByName.get(normalizeDriveName(file.semesterName)) || semesters.find(s => s.number === semesterNumberFromName(file.semesterName));
      if (!dep || !sem) continue;
      const materialName = String(file.materialName || 'مواد عامة').trim() || 'مواد عامة';
      const groupKey = `${dep.id}::${sem.id}::${normalizeDriveName(materialName)}`;
      if (!subjectGroups.has(groupKey)) subjectGroups.set(groupKey, { dep, sem, materialName, files: [] });
      subjectGroups.get(groupKey).files.push(file);
    }

    for (const group of subjectGroups.values()) {
      const subjectSeed = group.files[0];
      const existingSubject = await queryOne(ctx.env, `SELECT id FROM subjects WHERE active=1 AND department_id=? AND semester_id=? AND lower(trim(name_ar))=lower(trim(?)) LIMIT 1`,
        group.dep.id, group.sem.id, group.materialName);
      const subjectId = existingSubject?.id || `drive-subject-${subjectSeed.sectionId}-${subjectSeed.semesterId}-${normalizeDriveName(group.materialName).replace(/[^a-z0-9\u0600-\u06ff]+/gi, '-').slice(0, 100)}`;
      if (!existingSubject) {
        await ctx.env.DB.prepare(`INSERT INTO subjects (id,semester_id,department_id,code,name_ar,name_en,active,sort_order) VALUES (?,?,?,?,?,?,1,0)
          ON CONFLICT(id) DO NOTHING`)
          .bind(subjectId, group.sem.id, group.dep.id, `DRIVE:${subjectSeed.semesterId}:${normalizeDriveName(group.materialName)}`, group.materialName, group.materialName).run();
      }
      const folderIndexId = `drive-folder-${subjectId}`;
      await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,subject_id,name,modified_at,active,last_synced_at)
        VALUES (?,?,?,?,?,?,?, ?,1,CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,semester_id=excluded.semester_id,subject_id=excluded.subject_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
        .bind(folderIndexId, `apps-script-semester-${subjectSeed.semesterId}`, 'subject', group.dep.id, group.sem.id, subjectId, group.materialName, null).run();

      for (const file of group.files) {
        const materialId = `drive-material-${file.id}`;
        const alreadyRegistered = await queryOne(ctx.env, 'SELECT id FROM materials WHERE id=? OR drive_file_id=? LIMIT 1', materialId, file.id);
        if (alreadyRegistered) continue;
        const link = file.link || `https://drive.google.com/file/d/${file.id}/view`;
        await ctx.env.DB.prepare(`INSERT INTO materials
          (id,subject_id,title,description,drive_file_id,drive_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_modified_at,drive_web_view_url,pinned,source,last_synced_at)
          VALUES (?,?,?,?,?,?,?,?,1,0,?,?,?,?,'drive',CURRENT_TIMESTAMP)
          ON CONFLICT(id) DO UPDATE SET subject_id=excluded.subject_id,title=excluded.title,description=excluded.description,
          drive_url=excluded.drive_url,mime_type=excluded.mime_type,size_bytes=excluded.size_bytes,active=1,
          drive_parent_id=excluded.drive_parent_id,drive_modified_at=excluded.drive_modified_at,
          drive_web_view_url=excluded.drive_web_view_url,pinned=excluded.pinned,source='drive',last_synced_at=CURRENT_TIMESTAMP`)
          .bind(materialId, subjectId, file.name, file.description || null, file.id, link, 'application/pdf', Number(file.size || 0), file.id, file.modified || null, file.previewLink || link, file.pinned ? 1 : 0).run();
        const materialRow = await queryOne(ctx.env, 'SELECT * FROM materials WHERE id=?', materialId);
        await createOrRefreshContentNotificationDraft(ctx, 'materials', materialRow, a.session.staff_user_id);
        upserted++;
      }
    }

    await ctx.env.DB.prepare("UPDATE drive_sync_runs SET status='success', finished_at=CURRENT_TIMESTAMP, folders_seen=?, files_seen=?, materials_upserted=?, materials_deactivated=? WHERE id=?")
      .bind(foldersSeen, filesSeen, upserted, 0, syncId).run();
    return ok(ctx, { syncId, source: 'google-apps-script', generatedAt: index.generatedAt || null, foldersSeen, filesSeen, materialsUpserted: upserted, materialsDeactivated: 0 });
  } catch (e) {
    await ctx.env.DB.prepare("UPDATE drive_sync_runs SET status='failed', finished_at=CURRENT_TIMESTAMP, error_message=? WHERE id=?")
      .bind(String(e?.message || e).slice(0,1000), syncId).run();
    console.error(`[${ctx.requestId}] drive sync`, e);
    return error('DRIVE_SYNC_FAILED', 'تعذّر مزامنة المواد من Google Drive عبر Apps Script.', 502, ctx.requestId, ctx.cors, e?.message || 'unknown');
  }
}

export async function adminDriveSyncStatus(ctx) {
  const a = await adminDriveAuth(ctx); if (a.response) return a.response;
  const rows = await queryAll(ctx.env, 'SELECT * FROM drive_sync_runs ORDER BY started_at DESC LIMIT 10');
  return ok(ctx, rows);
}
