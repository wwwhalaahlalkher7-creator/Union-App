import assert from 'node:assert/strict';
import { routeText, routeVision, routeOcr, routeStt, routeTts } from '../backend/src/providers/router.js';

const env = {
  MISTRAL_API_KEY: 'test-mistral',
  GROQ_API_KEY: 'test-groq',
  FREE_AI_API_KEY: 'test-free',
  FREE_AI_BASE_URL: 'https://free.test',
  MISTRAL_BASE_URL: 'https://mistral.test',
  GROQ_BASE_URL: 'https://groq.test',
};

let calls = [];
let failProvider = null;
let failStatus = 503;

function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

globalThis.fetch = async (url, options = {}) => {
  const target = String(url);
  calls.push({ url: target, method: options.method || 'GET' });
  const provider = target.includes('mistral.test') ? 'mistral' : target.includes('groq.test') ? 'groq' : 'free.ai';
  if (provider === failProvider) return json({ error: 'forced test failure' }, failStatus);

  if (target.includes('/chat/completions')) return json({ choices: [{ message: { content: `ok-${provider}` } }], model: 'mock-model' });
  if (target.includes('/v1/ocr')) return json({ pages: [{ markdown: 'ocr-ok' }], model: 'mock-ocr' });
  if (target.includes('/audio/transcriptions')) return json({ text: `stt-${provider}`, model: 'mock-stt' });
  if (target.includes('/audio/speech')) return new Response(new Uint8Array([1, 2, 3]), { status: 200, headers: { 'content-type': 'audio/mpeg' } });
  if (target.includes('/image/describe/')) return json({ description: `vision-${provider}` });
  if (target.includes('/ocr/')) return json({ text: `ocr-${provider}` });
  if (target.includes('/stt/')) return json({ text: `stt-${provider}` });
  if (target.includes('/tts/')) return json({ audio_url: 'https://audio.test/x' });
  return json({ ok: true });
};

async function primary(name, fn, expected) {
  calls = [];
  failProvider = null;
  const result = await fn();
  assert.equal(result.provider, expected, `${name}: wrong primary provider`);
  console.log(`PASS ${name}: primary -> ${expected}`);
}

async function fallback(name, fn, failed, expected) {
  calls = [];
  failProvider = failed;
  failStatus = 503;
  const result = await fn();
  assert.equal(result.provider, expected, `${name}: fallback provider not selected`);
  assert.ok(calls.length >= 2, `${name}: fallback did not make a second attempt`);
  console.log(`PASS ${name}: ${failed} -> ${expected}`);
}

await primary('text', () => routeText(env, { messages: [{ role: 'user', content: 'hi' }] }), 'mistral');
await fallback('text', () => routeText(env, { messages: [{ role: 'user', content: 'hi' }] }), 'mistral', 'groq');
await fallback('vision', () => routeVision(env, { imageDataUrl: 'data:image/png;base64,AA==', prompt: 'analyze' }), 'mistral', 'groq');
await fallback('ocr', () => routeOcr(env, { file: new Uint8Array([1]), filename: 'a.png', contentType: 'image/png' }), 'mistral', 'free.ai');
await fallback('stt', () => routeStt(env, { file: new Uint8Array([1]), filename: 'a.mp3', contentType: 'audio/mpeg', language: 'ar' }), 'groq', 'mistral');
await fallback('tts', () => routeTts(env, { text: 'مرحبا', voice: 'test' }), 'groq', 'mistral');

calls = [];
failProvider = 'mistral';
failStatus = 400;
await assert.rejects(() => routeText(env, { messages: [{ role: 'user', content: 'bad' }] }), /mistral request failed/);
assert.equal(calls.length, 1, 'non-retryable 400 must not cascade');
console.log('PASS non-retryable 400: fallback stopped');

calls = [];
failProvider = null;
const requestedModel = await routeText(env, { model: 'mistral-small-2603', messages: [{ role: 'user', content: 'model-select' }] });
assert.equal(requestedModel.provider, 'mistral', 'requested model should select matching provider');
assert.equal(calls.length, 1, 'requested model should use only its matching route');
console.log('PASS requested model: selected matching provider');

let unknownModelFailed = false;
try { await routeText(env, { model: 'not-configured-model', messages: [{ role: 'user', content: 'unknown' }] }); } catch (e) { unknownModelFailed = Number(e?.status) === 400; }
assert.equal(unknownModelFailed, true, 'unknown requested model should return 400');
console.log('PASS unknown requested model: rejected');

console.log('EINO PROVIDER MATRIX PASSED');
