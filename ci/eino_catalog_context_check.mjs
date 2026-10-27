import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../services/api/src/eino.js', import.meta.url), 'utf8');
assert.match(source, /export async function retrieveStudentCatalog\(ctx, student, query\)/);
assert.match(source, /if \(!student\?\.departmentId\) return \[\]/);
assert.match(source, /\.slice\(0, 6\)/, 'query token count must be bounded');
assert.match(source, /s\.department_id = \?/);
assert.match(source, /m\.active = 1 AND s\.active = 1/);
assert.match(source, /LIMIT 5/);
assert.match(source, /termBinds/);
assert.match(source, /بيانات وصفية فقط وليست نصوص الملفات/);
assert.match(source, /لا تدّع أنك قرأت ملفًا/);
console.log('eino_catalog_context_check: OK');
