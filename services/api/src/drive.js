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
import { writeAudit } from './admin.js';
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

export async function deleteDriveFoldersViaAppsScript(ctx, folderIds) {
  const uniqueIds = [...new Set((Array.isArray(folderIds) ? folderIds : []).map(v => String(v || '').trim()).filter(Boolean))];
  if (!uniqueIds.length) return { deleted: [], count: 0 };
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  const tokenValue = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN || '').trim();
  if (!endpoint || !tokenValue) throw new Error('TRINEX Drive adapter is not configured.');
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ action: 'deleteFolders', token: tokenValue, folderIds: uniqueIds }),
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Apps Script folder delete failed (${response.status}).`);
  const data = await response.json();
  if (!data || data.success !== true || Number(data.failedCount || 0) > 0) {
    throw new Error(String(data?.error || `فشل حذف ${Number(data?.failedCount || 0)} مجلد من Google Drive.`));
  }
  return data;
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
    const depByDriveId = new Map();
    const semByDriveId = new Map();
    for (const d of departments) for (const n of departmentAliases(d)) depByName.set(normalizeDriveName(n), d);
    for (const s of semesters) for (const n of [s.name_ar, s.name_en, `semester ${s.number}`, `الفصل ${s.number}`, `سمستر ${s.number}`, `السمستر ${s.number}`]) if (n) semByName.set(normalizeDriveName(n), s);
    // Reuse prior immutable Drive IDs so renaming a department/semester folder
    // does not make its descendants look like deletions or unmapped content.
    const oldDepartmentFolders = await queryAll(ctx.env, "SELECT id,department_id FROM drive_folder_index WHERE folder_type='department' AND active=1");
    const oldSemesterFolders = await queryAll(ctx.env, "SELECT id,semester_id FROM drive_folder_index WHERE folder_type='semester' AND active=1");
    for (const row of oldDepartmentFolders) { const id = String(row.id || '').replace(/^apps-script-department-/, ''); const dep = departments.find(x => x.id === row.department_id); if (id && dep) depByDriveId.set(id, dep); }
    for (const row of oldSemesterFolders) { const id = String(row.id || '').replace(/^apps-script-semester-/, ''); const sem = semesters.find(x => x.id === row.semester_id); if (id && sem) semByDriveId.set(id, sem); }

    let foldersSeen = (Array.isArray(index.sections) ? index.sections.reduce((n, s) => n + 1 + (Array.isArray(s.semesters) ? s.semesters.length : 0), 0) : 0) + (Array.isArray(index.folders) ? index.folders.length : 0);
    let filesSeen = index.files.length;
    // Dedicated exam PDFs are managed through /admin/exams and must never leak into study sheets.
    const studyFiles = index.files.filter(file => file?.isExam !== true);
    let upserted = 0;
    let deactivated = 0;
    const activeDriveIds = [];

    // Keep the folder index coherent with the Apps Script source.
    for (const section of (Array.isArray(index.sections) ? index.sections : [])) {
      const dep = depByDriveId.get(String(section.id)) || depByName.get(normalizeDriveName(section.name));
      if (!dep) continue;
      depByDriveId.set(String(section.id), dep);
      const depIndexId = `apps-script-department-${section.id}`;
      await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,name,modified_at,active,last_synced_at)
        VALUES (?,?,?,?,?,?,1,CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
        .bind(depIndexId, 'apps-script-root', 'department', dep.id, section.name, null).run();
      for (const semester of (Array.isArray(section.semesters) ? section.semesters : [])) {
        const sem = semByDriveId.get(String(semester.id)) || semByName.get(normalizeDriveName(semester.name)) || semesters.find(s => s.number === semesterNumberFromName(semester.name));
        if (!sem) continue;
        semByDriveId.set(String(semester.id), sem);
        const semIndexId = `apps-script-semester-${semester.id}`;
        await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,name,modified_at,active,last_synced_at)
          VALUES (?,?,?,?,?,?,?,1,CURRENT_TIMESTAMP)
          ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,semester_id=excluded.semester_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
          .bind(semIndexId, depIndexId, 'semester', dep.id, sem.id, semester.name, null).run();
      }
    }

    // Reconcile the complete subject-folder inventory, including empty folders.
    // Subject identity is based on the immutable Drive folder ID, not its name,
    // so a rename updates the existing D1 row instead of creating a duplicate.
    const subjectGroups = new Map();
    const folderById = new Map((Array.isArray(index.folders) ? index.folders : []).map(folder => [String(folder.id), folder]));
    const resolveAcademic = (sectionName, semesterName, sectionDriveId, semesterDriveId) => {
      const dep = depByDriveId.get(String(sectionDriveId || '')) || depByName.get(normalizeDriveName(sectionName));
      const sem = semByDriveId.get(String(semesterDriveId || '')) || semByName.get(normalizeDriveName(semesterName)) || semesters.find(s => s.number === semesterNumberFromName(semesterName));
      return dep && sem ? { dep, sem } : null;
    };
    const ensureGroup = (folder, fallbackFile = null) => {
      const academic = resolveAcademic(
        folder?.sectionName || fallbackFile?.sectionName,
        folder?.semesterName || fallbackFile?.semesterName,
        folder?.sectionId || fallbackFile?.sectionId,
        folder?.semesterId || fallbackFile?.semesterId,
      );
      if (!academic) return null;
      const folderId = String(folder?.id || fallbackFile?.materialFolderId || '').trim();
      const materialName = String(folder?.name || fallbackFile?.materialName || 'مواد عامة').trim() || 'مواد عامة';
      const key = folderId ? `${academic.dep.id}::${academic.sem.id}::${folderId}` : `${academic.dep.id}::${academic.sem.id}::root:${normalizeDriveName(materialName)}`;
      if (!subjectGroups.has(key)) subjectGroups.set(key, { ...academic, materialName, folderId, files: [], folder });
      return subjectGroups.get(key);
    };
    let unmappedFolderCount = 0;
    for (const folder of (Array.isArray(index.folders) ? index.folders : [])) {
      if (!ensureGroup(folder)) unmappedFolderCount++;
    }
    if (unmappedFolderCount > 0) {
      throw new Error('فهرس Drive غير مكتمل: تعذّر ربط بعض المجلدات بقسم وفصل معروفين؛ أُوقفت مزامنة الحذف لحماية البيانات الحالية.');
    }
    for (const file of studyFiles) {
      const folder = file.materialFolderId ? folderById.get(String(file.materialFolderId)) : null;
      const group = ensureGroup(folder, file);
      if (group) group.files.push(file);
    }

    const activeSubjectIds = [];
    for (const group of subjectGroups.values()) {
      const folderId = group.folderId;
      const subjectId = folderId
        ? `drive-subject-${folderId}`
        : `drive-subject-root-${group.sem.id}-${group.dep.id}-${normalizeDriveName(group.materialName).replace(/[^a-z0-9\u0600-\u06ff]+/gi, '-').slice(0, 70)}`;
      const subjectCode = folderId ? `DRIVE:FOLDER:${folderId}` : `DRIVE:ROOT:${group.sem.id}:${normalizeDriveName(group.materialName)}`;
      await ctx.env.DB.prepare(`INSERT INTO subjects (id,semester_id,department_id,code,name_ar,name_en,active,sort_order) VALUES (?,?,?,?,?,?,1,0)
        ON CONFLICT(id) DO UPDATE SET semester_id=excluded.semester_id,department_id=excluded.department_id,code=excluded.code,name_ar=excluded.name_ar,name_en=excluded.name_en,active=1`)
        .bind(subjectId, group.sem.id, group.dep.id, subjectCode, group.materialName, group.materialName).run();
      activeSubjectIds.push(subjectId);

      if (folderId) {
        const folderIndexId = `apps-script-subject-${folderId}`;
        await ctx.env.DB.prepare(`INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,subject_id,name,modified_at,active,last_synced_at)
          VALUES (?,?,?,?,?,?,?,?,1,CURRENT_TIMESTAMP)
          ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,folder_type=excluded.folder_type,department_id=excluded.department_id,semester_id=excluded.semester_id,subject_id=excluded.subject_id,name=excluded.name,modified_at=excluded.modified_at,active=1,last_synced_at=CURRENT_TIMESTAMP`)
          .bind(folderIndexId, `apps-script-semester-${group.folder?.semesterId || ''}`, 'subject', group.dep.id, group.sem.id, subjectId, group.materialName, group.folder?.modified || null).run();
      }

      for (const file of group.files) {
        activeDriveIds.push(file.id);
        const materialId = `drive-material-${file.id}`;
        const previous = await queryOne(ctx.env, 'SELECT id, subject_id, drive_modified_at, active FROM materials WHERE id=?', materialId);
        const existingChunks = await queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM eino_material_chunks WHERE material_id=?', materialId);
        const link = file.link || `https://drive.google.com/file/d/${file.id}/view`;
        await ctx.env.DB.prepare(`INSERT INTO materials
          (id,subject_id,title,description,drive_file_id,drive_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_modified_at,drive_web_view_url,pinned,source,last_synced_at)
          VALUES (?,?,?,?,?,?,?,?,1,0,?,?,?,?,'drive',CURRENT_TIMESTAMP)
          ON CONFLICT(id) DO UPDATE SET subject_id=excluded.subject_id,title=excluded.title,description=excluded.description,
          drive_url=excluded.drive_url,mime_type=excluded.mime_type,size_bytes=excluded.size_bytes,active=1,
          drive_parent_id=excluded.drive_parent_id,drive_modified_at=excluded.drive_modified_at,
          drive_web_view_url=excluded.drive_web_view_url,pinned=excluded.pinned,source='drive',last_synced_at=CURRENT_TIMESTAMP`)
          .bind(materialId, subjectId, file.name, file.description || null, file.id, link, 'application/pdf', Number(file.size || 0), file.materialFolderId || file.semesterId, file.modified || null, file.previewLink || link, file.pinned ? 1 : 0).run();
        const needsIndex = !existingChunks || Number(existingChunks.count || 0) === 0 || !previous || previous.subject_id !== subjectId || String(previous.drive_modified_at || '') !== String(file.modified || '');
        if (needsIndex) {
          await ctx.env.DB.prepare(`INSERT INTO eino_material_index_queue (material_id,source_modified_at,status,attempts,last_error,queued_at,updated_at,finished_at)
            VALUES (?,?, 'queued',0,NULL,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,NULL)
            ON CONFLICT(material_id) DO UPDATE SET source_modified_at=excluded.source_modified_at,status='queued',attempts=0,last_error=NULL,queued_at=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP,finished_at=NULL`)
            .bind(materialId, file.modified || null).run();
        }
        upserted++;
      }
    }

    if (activeDriveIds.length !== studyFiles.length) {
      throw new Error('فهرس Drive غير مكتمل: تعذّر ربط بعض الملفات بقسم وفصل معروفين؛ أُوقفت مزامنة الحذف لحماية البيانات الحالية.');
    }

    if (activeSubjectIds.length) {
      const placeholders = activeSubjectIds.map(() => '?').join(',');
      await ctx.env.DB.prepare(`UPDATE subjects SET active=0 WHERE code LIKE 'DRIVE:%' AND id NOT IN (${placeholders})`).bind(...activeSubjectIds).run();
    } else {
      // Never interpret a valid but empty Drive index as an authoritative wipe.
      if (index.files.length > 0 || (Array.isArray(index.folders) && index.folders.length > 0)) {
        await ctx.env.DB.prepare("UPDATE subjects SET active=0 WHERE code LIKE 'DRIVE:%'").run();
      }
    }

    const activeSet = new Set(activeDriveIds);
    const rows = await queryAll(ctx.env, "SELECT drive_file_id FROM materials WHERE source='drive' AND active=1 AND drive_file_id IS NOT NULL");
    for (const row of rows) {
      if (!activeSet.has(row.drive_file_id)) {
        await ctx.env.DB.prepare("UPDATE materials SET active=0, updated_at=CURRENT_TIMESTAMP, last_synced_at=CURRENT_TIMESTAMP WHERE drive_file_id=? AND source='drive'")
          .bind(row.drive_file_id).run();
        await ctx.env.DB.prepare('DELETE FROM eino_material_chunks WHERE material_id IN (SELECT id FROM materials WHERE drive_file_id=? AND source=\'drive\')').bind(row.drive_file_id).run();
        await ctx.env.DB.prepare("UPDATE eino_material_index_queue SET status='cancelled',updated_at=CURRENT_TIMESTAMP,finished_at=CURRENT_TIMESTAMP WHERE material_id IN (SELECT id FROM materials WHERE drive_file_id=? AND source='drive')").bind(row.drive_file_id).run();
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


async function callAppsScriptDriveAction(ctx, action, fields = {}) {
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  const tokenValue = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN || '').trim();
  if (!endpoint || !tokenValue) throw new Error('TRINEX Drive adapter is not configured.');
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ action, token: tokenValue, ...fields }),
    signal: AbortSignal.timeout(action === 'uploadPdf' ? 60000 : 30000),
  });
  if (!response.ok) throw new Error(`Apps Script ${action} failed (${response.status}).`);
  const data = await response.json();
  if (!data || data.success !== true || Number(data.failedCount || 0) > 0) {
    throw new Error(String(data?.error || `فشل تنفيذ العملية ${action} في Google Drive.`));
  }
  return data;
}

function cleanDriveName(value) {
  const name = String(value || '').trim();
  if (!name || name.length > 180 || /[\\/\u0000-\u001f]/.test(name)) throw new Error('اسم العنصر غير صالح.');
  return name;
}

function driveFolderIdFromIndex(row, prefix) {
  const id = String(row?.id || '');
  return id.startsWith(prefix) ? id.slice(prefix.length) : '';
}

export async function adminDriveCreateFolder(ctx) {
  const auth = await adminDriveAuth(ctx); if (auth.response) return auth.response;
  try {
    const body = await parseJson(ctx.request);
    const semesterId = String(body.semesterId || body.semester_id || '').trim();
    const departmentId = String(body.departmentId || body.department_id || '').trim();
    const name = cleanDriveName(body.name);
    if (!semesterId || !departmentId) return error('DRIVE_PARENT_REQUIRED', 'القسم والفصل الدراسي مطلوبان.', 400, ctx.requestId, ctx.cors);
    const parent = await queryOne(ctx.env, "SELECT * FROM drive_folder_index WHERE folder_type='semester' AND semester_id=? AND department_id=? AND active=1 ORDER BY last_synced_at DESC LIMIT 1", semesterId, departmentId);
    const parentFolderId = driveFolderIdFromIndex(parent, 'apps-script-semester-');
    if (!parentFolderId) return error('DRIVE_SEMESTER_NOT_INDEXED', 'زامن مكتبة Drive أولاً حتى يمكن ربط الفصل بمجلده الحقيقي.', 409, ctx.requestId, ctx.cors);
    const created = await callAppsScriptDriveAction(ctx, 'createFolder', { parentFolderId, name });
    const subjectId = `drive-subject-${created.id}`;
    await ctx.env.DB.batch([
      ctx.env.DB.prepare("INSERT INTO subjects (id,semester_id,department_id,code,name_ar,name_en,active,sort_order) VALUES (?,?,?,?,?,?,1,0) ON CONFLICT(id) DO UPDATE SET name_ar=excluded.name_ar,name_en=excluded.name_en,active=1")
        .bind(subjectId, semesterId, departmentId, `DRIVE:FOLDER:${created.id}`, created.name, created.name),
      ctx.env.DB.prepare("INSERT INTO drive_folder_index (id,parent_id,folder_type,department_id,semester_id,subject_id,name,active,last_synced_at) VALUES (?,?,?,?,?,?,?,1,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET parent_id=excluded.parent_id,department_id=excluded.department_id,semester_id=excluded.semester_id,subject_id=excluded.subject_id,name=excluded.name,active=1,last_synced_at=CURRENT_TIMESTAMP")
        .bind(`apps-script-subject-${created.id}`, parent.id, 'subject', departmentId, semesterId, subjectId, created.name),
    ]);
    await writeAudit(ctx, auth.session.staff_user_id, 'create', 'drive_folder', created.id, { name: created.name, semester_id: semesterId });
    return ok(ctx, { id: subjectId, driveFolderId: created.id, name: created.name }, null, 201);
  } catch (e) {
    return error('DRIVE_FOLDER_CREATE_FAILED', 'تعذّر إنشاء مجلد المادة في Google Drive؛ لم يتم تسجيله في D1.', 502, ctx.requestId, ctx.cors, e?.message || 'unknown');
  }
}

export async function adminDriveRenameItem(ctx, itemId) {
  const auth = await adminDriveAuth(ctx); if (auth.response) return auth.response;
  try {
    const body = await parseJson(ctx.request);
    const name = cleanDriveName(body.name);
    const kind = String(body.kind || '').trim();
    if (kind === 'folder') {
      const subject = await queryOne(ctx.env, 'SELECT * FROM subjects WHERE id=? AND active=1', itemId);
      if (!subject) return error('DRIVE_SUBJECT_NOT_FOUND', 'مجلد المادة غير موجود.', 404, ctx.requestId, ctx.cors);
      const folder = await queryOne(ctx.env, "SELECT * FROM drive_folder_index WHERE subject_id=? AND folder_type='subject' AND active=1", itemId);
      const folderId = driveFolderIdFromIndex(folder, 'apps-script-subject-');
      if (!folderId) return error('DRIVE_FOLDER_NOT_INDEXED', 'لم يُعثر على معرّف مجلد Drive؛ نفّذ المزامنة أولاً.', 409, ctx.requestId, ctx.cors);
      const changed = await callAppsScriptDriveAction(ctx, 'renameFolder', { folderId, name });
      await ctx.env.DB.batch([
        ctx.env.DB.prepare('UPDATE subjects SET name_ar=?,name_en=? WHERE id=?').bind(changed.name, changed.name, itemId),
        ctx.env.DB.prepare('UPDATE drive_folder_index SET name=?,modified_at=?,last_synced_at=CURRENT_TIMESTAMP WHERE id=?').bind(changed.name, changed.modified || null, folder.id),
      ]);
      await writeAudit(ctx, auth.session.staff_user_id, 'rename', 'drive_folder', folderId, { name: changed.name });
      return ok(ctx, { id: itemId, name: changed.name });
    }
    if (kind === 'file') {
      const material = await queryOne(ctx.env, 'SELECT * FROM materials WHERE id=? AND active=1', itemId);
      if (!material?.drive_file_id || material.source !== 'drive') return error('DRIVE_FILE_NOT_FOUND', 'ملف Drive غير موجود أو غير قابل للتعديل.', 404, ctx.requestId, ctx.cors);
      const changed = await callAppsScriptDriveAction(ctx, 'renameFile', { fileId: material.drive_file_id, name });
      await ctx.env.DB.prepare('UPDATE materials SET title=?,drive_modified_at=?,updated_at=CURRENT_TIMESTAMP,last_synced_at=CURRENT_TIMESTAMP WHERE id=?').bind(changed.name, changed.modified || null, itemId).run();
      await writeAudit(ctx, auth.session.staff_user_id, 'rename', 'drive_file', material.drive_file_id, { name: changed.name });
      return ok(ctx, { id: itemId, name: changed.name });
    }
    return error('DRIVE_ITEM_KIND_INVALID', 'نوع العنصر غير مدعوم.', 400, ctx.requestId, ctx.cors);
  } catch (e) {
    return error('DRIVE_RENAME_FAILED', 'تعذّرت إعادة التسمية في Google Drive؛ لم يتم اعتماد تغيير في D1.', 502, ctx.requestId, ctx.cors, e?.message || 'unknown');
  }
}

export async function adminDriveUploadPdf(ctx) {
  const auth = await adminDriveAuth(ctx); if (auth.response) return auth.response;
  let uploaded = null;
  try {
    const body = await parseJson(ctx.request);
    const subjectId = String(body.subjectId || body.subject_id || '').trim();
    const name = cleanDriveName(body.name);
    const base64 = String(body.base64 || '');
    if (!subjectId || !base64) return error('DRIVE_UPLOAD_INPUT_INVALID', 'المادة وملف PDF مطلوبان.', 400, ctx.requestId, ctx.cors);
    if (base64.length > 28_000_000) return error('DRIVE_UPLOAD_TOO_LARGE', 'حجم ملف PDF يتجاوز 20MB.', 413, ctx.requestId, ctx.cors);
    const subject = await queryOne(ctx.env, 'SELECT * FROM subjects WHERE id=? AND active=1', subjectId);
    if (!subject) return error('DRIVE_SUBJECT_NOT_FOUND', 'مجلد المادة غير موجود.', 404, ctx.requestId, ctx.cors);
    const folder = await queryOne(ctx.env, "SELECT * FROM drive_folder_index WHERE subject_id=? AND folder_type='subject' AND active=1", subjectId);
    const parentFolderId = driveFolderIdFromIndex(folder, 'apps-script-subject-');
    if (!parentFolderId) return error('DRIVE_FOLDER_NOT_INDEXED', 'لم يُعثر على معرّف مجلد Drive؛ نفّذ المزامنة أولاً.', 409, ctx.requestId, ctx.cors);
    uploaded = await callAppsScriptDriveAction(ctx, 'uploadPdf', { parentFolderId, name, base64 });
    const materialId = `drive-material-${uploaded.id}`;
    await ctx.env.DB.batch([
      ctx.env.DB.prepare(`INSERT INTO materials (id,subject_id,title,drive_file_id,drive_url,drive_web_view_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_modified_at,source,last_synced_at)
        VALUES (?,?,?,?,?,?, 'application/pdf', ?,1,0,?,?, 'drive',CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET subject_id=excluded.subject_id,title=excluded.title,drive_url=excluded.drive_url,drive_web_view_url=excluded.drive_web_view_url,size_bytes=excluded.size_bytes,active=1,drive_parent_id=excluded.drive_parent_id,drive_modified_at=excluded.drive_modified_at,source='drive',last_synced_at=CURRENT_TIMESTAMP`)
        .bind(materialId, subjectId, uploaded.name, uploaded.id, uploaded.link, uploaded.previewLink, Number(uploaded.size || 0), parentFolderId, uploaded.modified || null),
      // Queue the new file immediately: do not wait for an administrator to run
      // a separate Drive sync before Eino can learn from this newly published PDF.
      ctx.env.DB.prepare(`INSERT INTO eino_material_index_queue
        (material_id,source_modified_at,status,attempts,last_error,queued_at,updated_at,finished_at)
        VALUES (?,?,'queued',0,NULL,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,NULL)
        ON CONFLICT(material_id) DO UPDATE SET source_modified_at=excluded.source_modified_at,status='queued',attempts=0,last_error=NULL,queued_at=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP,finished_at=NULL`)
        .bind(materialId, uploaded.modified || null),
      // Keep the audit row atomic with publication and indexing queue creation.
      // Returning an error after a successful upload would invite duplicate retries.
      ctx.env.DB.prepare('INSERT INTO audit_logs (id, actor_type, actor_id, action, resource_type, resource_id, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .bind(crypto.randomUUID(), 'staff', auth.session.staff_user_id, 'create', 'drive_file', uploaded.id,
          JSON.stringify({ name: uploaded.name, subject_id: subjectId })),
    ]);
    return ok(ctx, { id: materialId, driveFileId: uploaded.id, name: uploaded.name, link: uploaded.link }, null, 201);
  } catch (e) {
    if (uploaded) {
      return error('DRIVE_UPLOAD_RECONCILIATION_REQUIRED', 'تم رفع الملف إلى Google Drive لكن تعذّر تأكيد تسجيله في قاعدة البيانات. نفّذ مزامنة Drive قبل إعادة الرفع لتجنب إنشاء نسخة مكررة.', 502, ctx.requestId, ctx.cors, e?.message || 'unknown');
    }
    return error('DRIVE_UPLOAD_FAILED', 'تعذّر رفع ملف PDF إلى Google Drive.', 502, ctx.requestId, ctx.cors, e?.message || 'unknown');
  }
}

export async function adminDriveSyncStatus(ctx) {
  const a = await adminDriveAuth(ctx); if (a.response) return a.response;
  const rows = await queryAll(ctx.env, 'SELECT * FROM drive_sync_runs ORDER BY started_at DESC LIMIT 10');
  return ok(ctx, rows);
}


async function fetchAppsScriptExamIndex(ctx) {
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_URL || '').trim();
  const tokenValue = String(ctx.env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN || '').trim();
  if (!endpoint || !tokenValue) throw new Error('TRINEX Drive adapter is not configured.');
  const url = new URL(endpoint);
  url.searchParams.set('action', 'exams');
  url.searchParams.set('token', tokenValue);
  const response = await fetch(url.toString(), { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(25000) });
  if (!response.ok) throw new Error(`Apps Script exams index failed (${response.status}).`);
  const data = await response.json();
  if (data?.success !== true || !Array.isArray(data.subjects)) throw new Error(String(data?.error || 'فهرس الامتحانات غير صالح.'));
  return data;
}

export async function adminExams(ctx) {
  const auth = await adminDriveAuth(ctx); if (auth.response) return auth.response;
  try {
    const index = await fetchAppsScriptExamIndex(ctx);
    if (ctx.request.method === 'GET') return ok(ctx, index);
    const body = await parseJson(ctx.request);
    const action = String(body.action || '').trim();
    const subjects = index.subjects;
    if (action === 'ensure-folder') {
      const subjectFolderId = String(body.subjectFolderId || '').trim();
      const subject = subjects.find(x => x.subjectFolderId === subjectFolderId);
      if (!subject) return error('EXAM_SUBJECT_NOT_FOUND', 'المادة غير موجودة في مكتبة Drive.', 404, ctx.requestId, ctx.cors);
      if (subject.examsFolderId) return ok(ctx, { id: subject.examsFolderId, name: subject.examsFolderName, existing: true });
      const created = await callAppsScriptDriveAction(ctx, 'createFolder', { parentFolderId: subjectFolderId, name: 'exams' });
      await writeAudit(ctx, auth.session.staff_user_id, 'create', 'exam_folder', created.id, { subject: subject.subjectName, semester: subject.semesterName });
      return ok(ctx, { id: created.id, name: created.name, existing: false }, null, 201);
    }
    if (action === 'upload') {
      const subjectFolderId = String(body.subjectFolderId || '').trim();
      const subject = subjects.find(x => x.subjectFolderId === subjectFolderId);
      if (!subject) return error('EXAM_SUBJECT_NOT_FOUND', 'المادة غير موجودة في مكتبة Drive.', 404, ctx.requestId, ctx.cors);
      let parentFolderId = subject.examsFolderId;
      if (!parentFolderId) {
        const created = await callAppsScriptDriveAction(ctx, 'createFolder', { parentFolderId: subjectFolderId, name: 'exams' });
        parentFolderId = created.id;
      }
      const name = cleanDriveName(body.name);
      const base64 = String(body.base64 || '');
      if (!base64 || base64.length > 28_000_000) return error('EXAM_UPLOAD_INVALID', 'ملف PDF مطلوب ويجب ألا يتجاوز 20MB.', 400, ctx.requestId, ctx.cors);
      uploaded = await callAppsScriptDriveAction(ctx, 'uploadPdf', { parentFolderId, name, base64 });
      await writeAudit(ctx, auth.session.staff_user_id, 'create', 'exam_file', uploaded.id, { name: uploaded.name, subject: subject.subjectName, semester: subject.semesterName });
      return ok(ctx, { ...uploaded, examsFolderId: parentFolderId }, null, 201);
    }
    if (action === 'rename') {
      const fileId = String(body.fileId || '').trim();
      const subject = subjects.find(x => (x.files || []).some(f => f.id === fileId));
      if (!subject) return error('EXAM_FILE_NOT_FOUND', 'ملف الامتحان غير موجود أو لم تتم مزامنته.', 404, ctx.requestId, ctx.cors);
      const name = cleanDriveName(body.name);
      const changed = await callAppsScriptDriveAction(ctx, 'renameFile', { fileId, name });
      await writeAudit(ctx, auth.session.staff_user_id, 'rename', 'exam_file', fileId, { name: changed.name, subject: subject.subjectName });
      return ok(ctx, changed);
    }
    if (action === 'delete') {
      const fileId = String(body.fileId || '').trim();
      const subject = subjects.find(x => (x.files || []).some(f => f.id === fileId));
      if (!subject) return error('EXAM_FILE_NOT_FOUND', 'ملف الامتحان غير موجود أو لم تتم مزامنته.', 404, ctx.requestId, ctx.cors);
      const result = await callAppsScriptDriveAction(ctx, 'deleteFiles', { fileIds: [fileId] });
      await writeAudit(ctx, auth.session.staff_user_id, 'delete', 'exam_file', fileId, { subject: subject.subjectName });
      return ok(ctx, result);
    }
    return error('EXAM_ACTION_INVALID', 'عملية إدارة الامتحانات غير مدعومة.', 400, ctx.requestId, ctx.cors);
  } catch (e) {
    return error('EXAM_MANAGEMENT_FAILED', 'تعذّر إدارة الامتحانات عبر Google Drive.', 502, ctx.requestId, ctx.cors, e?.message || 'unknown');
  }
}
