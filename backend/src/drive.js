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
    let deactivated = 0;
    const activeDriveIds = [];

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
      const subjectId = `drive-subject-${subjectSeed.sectionId}-${subjectSeed.semesterId}-${normalizeDriveName(group.materialName).replace(/[^a-z0-9\u0600-\u06ff]+/gi, '-').slice(0, 100)}`;
      await ctx.env.DB.prepare(`INSERT INTO subjects (id,semester_id,department_id,code,name_ar,name_en,active,sort_order) VALUES (?,?,?,?,?,?,1,0)
        ON CONFLICT(id) DO UPDATE SET semester_id=excluded.semester_id,department_id=excluded.department_id,code=excluded.code,name_ar=excluded.name_ar,name_en=excluded.name_en,active=1`)
        .bind(subjectId, group.sem.id, group.dep.id, `DRIVE:${subjectSeed.semesterId}:${normalizeDriveName(group.materialName)}`, group.materialName, group.materialName).run();
      const folderIndexId = `drive-folder-${subjectId}`;
      await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,subject_id,name,modified_at,active,last_synced_at)
        VALUES (?,?,?,?,?,?,?, ?,1,CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,semester_id=excluded.semester_id,subject_id=excluded.subject_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
        .bind(folderIndexId, `apps-script-semester-${subjectSeed.semesterId}`, 'subject', group.dep.id, group.sem.id, subjectId, group.materialName, null).run();

      for (const file of group.files) {
        activeDriveIds.push(file.id);
        const materialId = `drive-material-${file.id}`;
        const link = file.link || `https://drive.google.com/file/d/${file.id}/view`;
        await ctx.env.DB.prepare(`INSERT INTO materials
          (id,subject_id,title,description,drive_file_id,drive_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_modified_at,drive_web_view_url,pinned,source,last_synced_at)
          VALUES (?,?,?,?,?,?,?,?,1,0,?,?,?,?,'drive',CURRENT_TIMESTAMP)
          ON CONFLICT(id) DO UPDATE SET subject_id=excluded.subject_id,title=excluded.title,description=excluded.description,
          drive_url=excluded.drive_url,mime_type=excluded.mime_type,size_bytes=excluded.size_bytes,active=1,
          drive_parent_id=excluded.drive_parent_id,drive_modified_at=excluded.drive_modified_at,
          drive_web_view_url=excluded.drive_web_view_url,pinned=excluded.pinned,source='drive',last_synced_at=CURRENT_TIMESTAMP`)
          .bind(materialId, subjectId, file.name, file.description || null, file.id, link, 'application/pdf', Number(file.size || 0), file.id, file.modified || null, file.previewLink || link, file.pinned ? 1 : 0).run();
        upserted++;
      }
    }

    const activeSet = new Set(activeDriveIds);
    const rows = await queryAll(ctx.env, "SELECT drive_file_id FROM materials WHERE source='drive' AND active=1 AND drive_file_id IS NOT NULL");
    for (const row of rows) {
      if (!activeSet.has(row.drive_file_id)) {
        await ctx.env.DB.prepare("UPDATE materials SET active=0, updated_at=CURRENT_TIMESTAMP, last_synced_at=CURRENT_TIMESTAMP WHERE drive_file_id=? AND source='drive'")
          .bind(row.drive_file_id).run();
        deactivated++;
      }
    }

    await ctx.env.DB.prepare("UPDATE drive_folder_index SET active=0 WHERE last_synced_at < (SELECT started_at FROM drive_sync_runs WHERE id=?)")
      .bind(syncId).run();
    await ctx.env.DB.prepare("UPDATE drive_sync_runs SET status='success', finished_at=CURRENT_TIMESTAMP, folders_seen=?, files_seen=?, materials_upserted=?, materials_deactivated=? WHERE id=?")
      .bind(foldersSeen, filesSeen, upserted, deactivated, syncId).run();
    return ok(ctx, { syncId, source: 'google-apps-script', generatedAt: index.generatedAt || null, foldersSeen, filesSeen, materialsUpserted: upserted, materialsDeactivated: deactivated });
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
