import { readFileSync } from 'node:fs';
const eino = readFileSync('backend/src/eino.js','utf8');
const index = readFileSync('backend/src/index.js','utf8');
const repo = readFileSync('flutter/lib/data/repositories/eino_repository.dart','utf8');
const checks = [
  ['hierarchical summarizer', /async function summarizeLongText\(ctx, text, signal\)/.test(eino)],
  ['50k input guard', /text\.length > 50000/.test(eino)],
  ['120s timeout', /120000/.test(eino)],
  ['summary route', /path === '\/eino\/long-summary'/.test(index)],
  ['flutter longSummary', /Future<String> longSummary\(/.test(repo)],
];
for (const [name, ok] of checks) if (!ok) throw new Error(`FAIL: ${name}`);
console.log('EINO LONG SUMMARY CHECK PASSED');
