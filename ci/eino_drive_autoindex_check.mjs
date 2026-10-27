import fs from 'node:fs';
import assert from 'node:assert/strict';
const drive = fs.readFileSync(new URL('../services/api/src/drive.js', import.meta.url), 'utf8');
const eino = fs.readFileSync(new URL('../services/api/src/eino.js', import.meta.url), 'utf8');
const index = fs.readFileSync(new URL('../services/api/src/index.js', import.meta.url), 'utf8');
const appsScript = fs.readFileSync(new URL('../services/api/App Script/TRINEX Drive.gs', import.meta.url), 'utf8');
const migration = fs.readFileSync(new URL('../services/api/migrations/0033_eino_index_queue.sql', import.meta.url), 'utf8');
const checks = [
  ['queue schema includes retries and states', /status TEXT NOT NULL DEFAULT 'queued'/.test(migration) && /attempts INTEGER NOT NULL DEFAULT 0/.test(migration)],
  ['Drive sync queues new and changed PDFs', /needsIndex = !existingChunks/.test(drive) && /INSERT INTO eino_material_index_queue/.test(drive)],
  ['direct PDF upload queues indexing atomically with D1 material registration', /export async function adminDriveUploadPdf[\s\S]*?ctx\.env\.DB\.batch\(\[[\s\S]*?INSERT INTO eino_material_index_queue/.test(drive)],
  ['removed PDFs lose stale chunks', /DELETE FROM eino_material_chunks WHERE material_id IN/.test(drive)],
  ['cron indexing is bounded to two PDFs', /Math\.min\(2, Number\(limit\)/.test(eino)],
  ['interrupted jobs recover after timeout', /updated_at < datetime\('now','-10 minutes'\)/.test(eino)],
  ['academic folder moves trigger re-indexing', /previous\.subject_id !== subjectId/.test(drive)],
  ['automatic queue processor runs on scheduled trigger', /processPendingEinoMaterialIndexes\(env, 2\)/.test(index)],
  ['queue retries are capped at three attempts', /attempts\+1 >= 3/.test(eino)],
  ['manual endpoint remains protected', /if \(!internalWorker\)/.test(eino)],
  ['exam PDFs excluded from regular material sync', drive.includes('index.files.filter(file => file?.isExam !== true') && appsScript.includes('isExam: !!examMode')],
];
for (const [name, pass] of checks) console.log(`${pass ? 'PASS' : 'FAIL'} ${name}`);
assert.ok(checks.every(([, pass]) => pass), 'Eino Drive auto-index checks failed');
console.log(`EINO DRIVE AUTO-INDEX CHECK PASSED: ${checks.length} checks`);

