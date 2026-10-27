import assert from 'node:assert/strict';
import { adminDriveSync } from '../services/api/src/drive.js';

const statements = [];
const syncUpdates = [];
const queues = [];
const department = {
  id: 'dept-ee', name_ar: 'الهندسة الكهربائية والإلكترونية',
  name_en: 'Electrical and Electronic Engineering', code: 'ee', active: 1,
};
const semester = {
  id: 'semester-1', name_ar: 'الفصل الأول', name_en: 'Semester 1', number: 1, active: 1,
};
const session = {
  id: 'session-1', student_id: null, staff_user_id: 'staff-1', revoked_at: null,
  expires_at: '2999-01-01 00:00:00',
};
const staff = {
  staff_user_id: 'staff-1', staff_user_id_login: 'academic-manager',
  staff_email: 'manager@example.test', staff_display_name: 'Test Manager',
  staff_role_id: 'academic_manager', staff_role_name: 'Academic Manager', staff_active: 1,
};

const index = {
  success: true,
  generatedAt: '2026-10-27T09:00:00.000Z',
  sections: [{
    id: 'dep-folder-1', name: 'Electrical and Electronic Engineering',
    semesters: [{ id: 'sem-folder-1', name: 'Semester 1' }],
  }],
  folders: [{
    id: 'subject-folder-1', name: 'Circuits', sectionName: 'Electrical and Electronic Engineering',
    semesterName: 'Semester 1', sectionId: 'dep-folder-1', semesterId: 'sem-folder-1',
    modified: '2026-10-27T08:59:00.000Z',
  }],
  files: [
    {
      id: 'file-study-1', name: 'Circuits.pdf', description: 'study notes',
      link: 'https://drive.google.com/file/d/file-study-1/view',
      previewLink: 'https://drive.google.com/file/d/file-study-1/preview', size: 1234,
      modified: '2026-10-27T08:58:00.000Z', materialFolderId: 'subject-folder-1',
      sectionName: 'Electrical and Electronic Engineering', semesterName: 'Semester 1',
      sectionId: 'dep-folder-1', semesterId: 'sem-folder-1', materialName: 'Circuits', isExam: false,
    },
    {
      id: 'file-exam-1', name: 'Circuits-Final.pdf', description: 'exam',
      link: 'https://drive.google.com/file/d/file-exam-1/view', size: 4321,
      modified: '2026-10-27T08:58:00.000Z', materialFolderId: 'subject-folder-1',
      sectionName: 'Electrical and Electronic Engineering', semesterName: 'Semester 1',
      sectionId: 'dep-folder-1', semesterId: 'sem-folder-1', materialName: 'Circuits', isExam: true,
    },
  ],
};

function prepare(sql) {
  const item = { sql, bindings: [] };
  item.bind = (...values) => { item.bindings = values; return item; };
  item.first = async () => {
    statements.push({ ...item, kind: 'first' });
    if (/FROM sessions WHERE access_token_hash/i.test(sql)) return session;
    if (/FROM staff_users\s+su\s+JOIN roles/i.test(sql)) return staff;
    if (/SELECT id, subject_id, drive_modified_at, active FROM materials/i.test(sql)) return null;
    if (/SELECT COUNT\(\*\) AS count FROM eino_material_chunks/i.test(sql)) return { count: 0 };
    return null;
  };
  item.all = async () => {
    statements.push({ ...item, kind: 'all' });
    if (/SELECT \* FROM departments WHERE active = 1/i.test(sql)) return { results: [department] };
    if (/SELECT \* FROM semesters WHERE active = 1/i.test(sql)) return { results: [semester] };
    if (/SELECT id,department_id FROM drive_folder_index/i.test(sql)) return { results: [] };
    if (/SELECT id,semester_id FROM drive_folder_index/i.test(sql)) return { results: [] };
    if (/SELECT drive_file_id FROM materials WHERE source='drive' AND active=1/i.test(sql)) {
      return { results: [{ drive_file_id: 'file-study-1' }] };
    }
    return { results: [] };
  };
  item.run = async () => {
    statements.push({ ...item, kind: 'run' });
    if (/INSERT INTO eino_material_index_queue/i.test(sql)) queues.push({ ...item, kind: 'queue' });
    if (/UPDATE drive_sync_runs SET status='success'/i.test(sql)) syncUpdates.push({ ...item });
    return { success: true, meta: { changes: 1 } };
  };
  return item;
}

const env = {
  GOOGLE_APPS_SCRIPT_DRIVE_URL: 'https://apps-script.example.test/exec',
  GOOGLE_APPS_SCRIPT_DRIVE_TOKEN: 'test-token',
  DB: { prepare },
};
const previousFetch = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(String(input));
  assert.equal(url.origin + url.pathname, env.GOOGLE_APPS_SCRIPT_DRIVE_URL);
  assert.equal(url.searchParams.get('action'), 'index');
  assert.equal(url.searchParams.get('token'), 'test-token');
  assert.equal(init.method || 'GET', 'GET');
  return new Response(JSON.stringify(index), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
};

try {
  const request = new Request('https://worker.example.test/api/v1/admin/drive/sync?nocache=1', {
    headers: { authorization: 'Bearer test-session' },
  });
  const response = await adminDriveSync({
    env, request, url: new URL(request.url), requestId: 'drive-sync-integration', cors: {},
  });
  const body = await response.json();
  assert.equal(response.status, 200, `sync failed: ${JSON.stringify(body)}`);
  assert.equal(body.success, true);
  assert.equal(body.data.materialsUpserted, 1);
  assert.equal(body.data.materialsDeactivated, 0);
  assert.ok(statements.some((s) => /INSERT INTO subjects/i.test(s.sql) && s.bindings.includes('drive-subject-subject-folder-1')),
    'subject folder should reconcile to a stable D1 subject id');
  assert.ok(statements.some((s) => /INSERT INTO materials/i.test(s.sql) && s.bindings.includes('drive-material-file-study-1')),
    'study PDF should be stored as a D1 material');
  assert.equal(queues.length, 1, 'new study PDF should be queued for Eino indexing');
  assert.equal(queues[0].bindings[0], 'drive-material-file-study-1');
  assert.ok(!statements.some((s) => s.bindings.includes('drive-material-file-exam-1')),
    'exam PDFs must not enter the ordinary materials table or Eino index queue');
  assert.equal(syncUpdates.length, 1, 'successful full index should mark sync run as successful');
  console.log('Drive ↔ D1 reconciliation integration test passed: stable subject, material upsert, PDF queue, exam isolation and sync completion.');
} finally {
  globalThis.fetch = previousFetch;
}
