import assert from 'node:assert/strict';
import { processPendingEinoMaterialIndexes } from '../services/api/src/eino.js';

const sampleText = [
  'Electrical circuits study notes. Ohms law states that voltage equals current multiplied by resistance.',
  'Kirchhoff current law: the total current entering a junction equals the total current leaving that junction.',
  'Kirchhoff voltage law: the algebraic sum of voltage changes around a closed loop is zero.',
  'These equations are useful for analyzing direct-current circuits and calculating unknown branch currents.',
].join('\n\n');
const captured = { sql: [], batches: [], downloadCount: 0, ocrCount: 0, ocrBody: null };
const queueRow = { materialId: 'drive-material-file-1', attempts: 0 };
let queueStatus = 'queued';

function statement(sql) {
  const result = {
    sql,
    bindings: [],
    bind(...values) { this.bindings = values; return this; },
    async first() {
      captured.sql.push({ kind: 'first', sql: this.sql, bindings: this.bindings });
      if (/SELECT m\.id, m\.title, m\.drive_file_id/i.test(this.sql)) {
        return {
          id: 'drive-material-file-1',
          title: 'Circuits.pdf',
          drive_file_id: 'file-1',
          mime_type: 'application/pdf',
          departmentId: 'dept-1',
          semesterId: 'semester-1',
        };
      }
      return null;
    },
    async all() {
      captured.sql.push({ kind: 'all', sql: this.sql, bindings: this.bindings });
      if (/SELECT q\.material_id AS materialId/i.test(this.sql)) {
        return { results: queueStatus === 'queued' ? [queueRow] : [] };
      }
      return { results: [] };
    },
    async run() {
      captured.sql.push({ kind: 'run', sql: this.sql, bindings: this.bindings });
      if (/SET status='processing'/i.test(this.sql)) {
        if (queueStatus !== 'queued') return { success: true, meta: { changes: 0 } };
        queueStatus = 'processing';
        return { success: true, meta: { changes: 1 } };
      }
      if (/SET status='done'/i.test(this.sql)) queueStatus = 'done';
      if (/SET status=CASE WHEN attempts\+1/i.test(this.sql)) queueStatus = 'queued';
      return { success: true, meta: { changes: 1 } };
    },
  };
  return result;
}

const env = {
  MISTRAL_API_KEY: 'mock-key',
  MISTRAL_BASE_URL: 'https://api.mistral.ai',
  EINO_MISTRAL_OCR_MODEL: 'mistral-ocr-latest',
  DB: {
    prepare(sql) { return statement(sql); },
    async batch(statements) {
      captured.batches.push(statements);
      return statements.map(() => ({ success: true, meta: { changes: 1 } }));
    },
  },
};

const previousFetch = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = String(input);
  if (url.startsWith('https://drive.google.com/uc?')) {
    captured.downloadCount++;
    return new Response('%PDF-1.7\nmock pdf bytes', {
      status: 200,
      headers: { 'content-type': 'application/pdf', 'content-length': '24' },
    });
  }
  if (url === 'https://api.mistral.ai/v1/ocr') {
    captured.ocrCount++;
    captured.ocrBody = JSON.parse(init.body);
    return new Response(JSON.stringify({
      model: 'mistral-ocr-latest',
      pages: [{ markdown: sampleText }],
    }), { status: 200, headers: { 'content-type': 'application/json' } });
  }
  throw new Error(`Unexpected network request in test: ${url}`);
};

try {
  const result = await processPendingEinoMaterialIndexes(env, 2);
  assert.equal(result.processed, 1);
  assert.equal(result.results[0].materialId, 'drive-material-file-1');
  assert.equal(result.results[0].status, 'done');
  assert.equal(captured.downloadCount, 1, 'queued file should be downloaded from Drive');
  assert.equal(captured.ocrCount, 1, 'downloaded PDF should be sent through the configured OCR route');
  assert.equal(captured.ocrBody.model, 'mistral-ocr-latest');
  assert.ok(captured.batches.length === 1, 'chunk replacement should use a single D1 batch');
  assert.ok(captured.batches[0].some((s) => /DELETE FROM eino_material_chunks/i.test(s.sql)));
  const inserts = captured.batches[0].filter((s) => /INSERT INTO eino_material_chunks/i.test(s.sql));
  assert.ok(inserts.length > 0, 'OCR text should be split and persisted into searchable chunks');
  assert.ok(inserts.some((s) => s.bindings.includes('dept-1')));
  assert.equal(queueStatus, 'done', 'successful index must finish the queue item');
  console.log(`Eino PDF pipeline integration test passed: Drive download -> OCR -> ${inserts.length} searchable chunk(s) -> queue done.`);
} finally {
  globalThis.fetch = previousFetch;
}
