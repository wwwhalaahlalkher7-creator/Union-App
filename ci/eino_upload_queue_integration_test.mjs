import assert from 'node:assert/strict';
import { adminDriveUploadPdf } from '../services/api/src/drive.js';

const captured = { batches: [], runs: [], fetchBody: null, failNextBatch: false };
const session = {
  id: 'session-1',
  student_id: null,
  staff_user_id: 'staff-1',
  revoked_at: null,
  expires_at: '2999-01-01 00:00:00',
};
const staff = {
  staff_user_id: 'staff-1',
  staff_user_id_login: 'academic-manager',
  staff_email: 'manager@example.test',
  staff_display_name: 'Test Manager',
  staff_role_id: 'academic_manager',
  staff_role_name: 'Academic Manager',
  staff_active: 1,
};

function statement(sql) {
  const item = {
    sql,
    bindings: [],
    bind(...values) { this.bindings = values; return this; },
    async first() {
      if (/FROM sessions\b/i.test(sql)) return session;
      if (/FROM staff_users\s+su\s+JOIN roles/i.test(sql)) return staff;
      if (/FROM subjects\b/i.test(sql)) return { id: 'subject-1', active: 1, department_id: 'dept-1', semester_id: 'semester-1' };
      if (/FROM drive_folder_index\b/i.test(sql)) return { id: 'apps-script-subject-folder-1', active: 1, subject_id: 'subject-1' };
      return null;
    },
    async all() { return { results: [] }; },
    async run() { captured.runs.push(this); return { success: true, meta: { changes: 1 } }; },
  };
  return item;
}

const env = {
  GOOGLE_APPS_SCRIPT_DRIVE_URL: 'https://apps-script.example.test/exec',
  GOOGLE_APPS_SCRIPT_DRIVE_TOKEN: 'test-token',
  DB: {
    prepare: statement,
    async batch(statements) {
      captured.batches.push(statements);
      if (captured.failNextBatch) {
        captured.failNextBatch = false;
        throw new Error('injected D1 commit failure');
      }
      return statements.map(() => ({ success: true, meta: { changes: 1 } }));
    },
  },
};

const previousFetch = globalThis.fetch;
globalThis.fetch = async (url, init = {}) => {
  assert.equal(String(url), env.GOOGLE_APPS_SCRIPT_DRIVE_URL);
  captured.fetchBody = JSON.parse(init.body);
  return new Response(JSON.stringify({
    success: true,
    id: 'file-1',
    name: 'Circuits.pdf',
    size: 128,
    modified: '2026-10-27T09:00:00.000Z',
    link: 'https://drive.google.com/file/d/file-1/view',
    previewLink: 'https://drive.google.com/file/d/file-1/preview',
  }), { status: 200, headers: { 'content-type': 'application/json' } });
};

try {
  const request = new Request('https://worker.example.test/api/v1/admin/drive/files', {
    method: 'POST',
    headers: { authorization: 'Bearer test-session', 'content-type': 'application/json' },
    body: JSON.stringify({ subjectId: 'subject-1', name: 'Circuits.pdf', base64: 'JVBERi0xLjQK' }),
  });
  const response = await adminDriveUploadPdf({
    env,
    request,
    requestId: 'integration-test',
    cors: {},
  });
  assert.equal(response.status, 201, `upload failed with HTTP ${response.status}: ${await response.clone().text()}`);
  const payload = await response.json();
  assert.equal(payload.success, true);
  assert.equal(payload.data.id, 'drive-material-file-1');
  assert.equal(captured.fetchBody.action, 'uploadPdf');
  assert.equal(captured.fetchBody.parentFolderId, 'folder-1');
  assert.equal(captured.fetchBody.token, env.GOOGLE_APPS_SCRIPT_DRIVE_TOKEN);
  assert.equal(captured.batches.length, 1, 'material record and indexing queue should share one D1 batch');
  assert.equal(captured.batches[0].length, 3, 'the D1 batch must contain material, queue and audit writes');
  assert.match(captured.batches[0][0].sql, /INSERT INTO materials/);
  assert.match(captured.batches[0][1].sql, /INSERT INTO eino_material_index_queue/);
  assert.equal(captured.batches[0][1].bindings[0], 'drive-material-file-1');
  assert.equal(captured.batches[0][1].bindings[1], '2026-10-27T09:00:00.000Z');
  assert.match(captured.batches[0][2].sql, /INSERT INTO audit_logs/);
  assert.equal(captured.batches[0][2].bindings[4], 'drive_file');
  // A Drive upload can succeed before D1 fails. The API must not misleadingly
  // report that Drive failed or encourage an immediate duplicate upload.
  captured.failNextBatch = true;
  const failedCommit = await adminDriveUploadPdf({
    env,
    request: new Request('https://worker.example.test/api/v1/admin/drive/files', {
      method: 'POST',
      headers: { authorization: 'Bearer test-session', 'content-type': 'application/json' },
      body: JSON.stringify({ subjectId: 'subject-1', name: 'Circuits.pdf', base64: 'JVBERi0xLjQK' }),
    }),
    requestId: 'integration-test-failure',
    cors: {},
  });
  const failurePayload = await failedCommit.json();
  assert.equal(failedCommit.status, 502);
  assert.equal(failurePayload.error.code, 'DRIVE_UPLOAD_RECONCILIATION_REQUIRED');
  assert.match(failurePayload.error.message, /مزامنة Drive قبل إعادة الرفع/);
  console.log('Eino upload queue integration test passed: atomic material+queue+audit, plus clear recovery when Drive succeeds but D1 commit fails.');
} finally {
  globalThis.fetch = previousFetch;
}
