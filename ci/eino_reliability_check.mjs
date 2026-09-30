import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const router = readFileSync(new URL('../backend/src/providers/router.js', import.meta.url), 'utf8');
assert.match(router, /CIRCUIT_FAILURE_THRESHOLD\s*=\s*3/);
assert.match(router, /CIRCUIT_COOLDOWN_MS\s*=\s*30_000/);
assert.match(router, /MAX_PROVIDER_ATTEMPTS\s*=\s*2/);
assert.match(router, /retryAfterMs/);
assert.match(router, /fallback/);
assert.match(router, /normalizeResult/);
console.log('eino_reliability_check: OK');
