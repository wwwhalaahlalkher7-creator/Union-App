import assert from 'node:assert/strict';
import { routeText, routeVision, routeOcr, routeStt, routeTts, routeWebSearch, routeImageGeneration, routeFileAnalysis, resetProviderCircuitState } from '../backend/src/providers/router.js';

const env = {
  MISTRAL_API_KEY: 'test-mistral',
  GROQ_API_KEY: 'test-groq',
  GEMINI_API_KEY: 'test-gemini',
  FREE_AI_API_KEY: 'test-free',
  FREE_AI_BASE_URL: 'https://free.test',
  EINO_MISTRAL_BASE_URL: 'https://mistral.test',
  EINO_MISTRAL_TTS_VOICE_ID: 'test-voice',
  EINO_GROQ_BASE_URL: 'https://groq.test',
  EINO_GEMINI_BASE_URL: 'https://gemini.test/v1beta',
};

let calls = [];
let failProvider = null;
let failProviders = new Set();
let failStatus = 503;
let emptySearchProvider = null;

function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

globalThis.fetch = async (url, options = {}) => {
  const target = String(url);
  calls.push({ url: target, method: options.method || 'GET' });
  const provider = target.includes('mistral.test') ? 'mistral' : target.includes('groq.test') ? 'groq' : target.includes('gemini.test') ? 'gemini' : target.includes('api.tavily.com') ? 'tavily' : target.includes('api.exa.ai') ? 'exa' : target.includes('api.deepgram.com') ? 'deepgram' : 'free.ai';
  if (provider === failProvider || failProviders.has(provider)) return json({ error: 'forced test failure' }, failStatus);
  if (provider === 'tavily') return json({ results: emptySearchProvider === 'tavily' ? [] : [{ title: 'TRINEX', url: 'https://example.test/trinex', content: 'fresh result' }] });
  if (provider === 'exa') return json({ results: emptySearchProvider === 'exa' ? [] : [{ title: 'Academic', url: 'https://example.test/paper', highlights: ['fresh academic result'] }] });
  if (provider === 'deepgram') return json({ results: { channels: [{ alternatives: [{ transcript: 'deepgram-ok' }] }] }, metadata: { model_info: { 'nova-3': {} } } });
  if (provider === 'gemini' && target.includes('/upload/v1beta/files')) {
    return new Response(null, { status: 200, headers: { 'x-goog-upload-url': 'https://gemini.test/upload-session' } });
  }
  if (target.includes('/upload-session')) return json({ file: { uri: 'https://gemini.test/files/mock', mimeType: 'audio/mpeg' } });

  if (target.includes('gemini.test') && target.includes('/interactions')) return json({ output_text: 'gemini-ok', output_audio: { data: 'AQID' } });
  if (target.includes('gemini.test') && target.includes(':generateContent')) return json({ candidates: [{ content: { parts: [{ text: 'gemini-ok' }] } }], modelVersion: 'gemini-mock' });
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
  failProviders = new Set();
  const result = await fn();
  assert.equal(result.provider, expected, `${name}: wrong primary provider`);
  console.log(`PASS ${name}: primary -> ${expected}`);
}

async function fallback(name, fn, failed, expected) {
  calls = [];
  failProvider = failed;
  failProviders = new Set();
  failStatus = 503;
  const result = await fn();
  assert.equal(result.provider, expected, `${name}: fallback provider not selected`);
  assert.ok(calls.length >= 2, `${name}: fallback did not make a second attempt`);
  console.log(`PASS ${name}: ${failed} -> ${expected}`);
}

await primary('chat text', () => routeText(env, { task: 'chat', messages: [{ role: 'user', content: 'hi' }] }), 'groq');
await primary('academic text', () => routeText(env, { task: 'academic', messages: [{ role: 'user', content: 'اشرح polymorphism' }] }), 'mistral');
await fallback('academic text', () => routeText(env, { task: 'academic', messages: [{ role: 'user', content: 'اشرح polymorphism' }] }), 'mistral', 'gemini');
await fallback('chat text 429', () => routeText(env, { task: 'chat', messages: [{ role: 'user', content: 'rate-limit' }] }), 'groq', 'mistral');
await fallback('vision', () => routeVision(env, { imageDataUrl: 'data:image/png;base64,AA==', prompt: 'analyze' }), 'mistral', 'groq');
await fallback('ocr', () => routeOcr(env, { file: new Uint8Array([1]), filename: 'a.png', contentType: 'image/png' }), 'mistral', 'free.ai');
await fallback('stt', () => routeStt(env, { file: new Uint8Array([1]), filename: 'a.mp3', contentType: 'audio/mpeg', language: 'ar' }), 'groq', 'mistral');
await fallback('tts', () => routeTts(env, { text: 'مرحبا', voice: 'test' }), 'groq', 'mistral');

calls = [];
resetProviderCircuitState();
failProviders = new Set(['groq', 'mistral']);
const geminiText = await routeText(env, { messages: [{ role: 'user', content: 'gemini fallback' }] });
assert.equal(geminiText.provider, 'gemini', 'text: groq -> gemini fallback failed');
console.log('PASS text: groq -> gemini');

calls = [];
resetProviderCircuitState();
failProviders = new Set(['groq', 'mistral']);
const geminiVision = await routeVision(env, { imageDataUrl: 'data:image/png;base64,AA==', prompt: 'gemini vision fallback' });
assert.equal(geminiVision.provider, 'gemini', 'vision: groq+mistral -> gemini fallback failed');
console.log('PASS vision: groq+mistral -> gemini');

calls = [];
resetProviderCircuitState();
failProviders = new Set(['groq', 'mistral']);
const geminiStt = await routeStt(env, { file: new Uint8Array([1]), filename: 'a.mp3', contentType: 'audio/mpeg', language: 'ar' });
assert.equal(geminiStt.provider, 'gemini', 'stt: groq+mistral -> gemini fallback failed');
console.log('PASS stt: groq+mistral -> gemini');

calls = [];
resetProviderCircuitState();
failProviders = new Set(['groq', 'mistral']);
const geminiTts = await routeTts(env, { text: 'مرحبا بإينو' });
assert.equal(geminiTts.provider, 'gemini', 'tts: groq+mistral -> gemini fallback failed');
assert.equal(geminiTts.contentType, 'audio/wav');
console.log('PASS tts: groq+mistral -> gemini');

calls = [];
resetProviderCircuitState();
failProviders = new Set();
failProvider = 'mistral';
failStatus = 400;
await assert.rejects(() => routeText(env, { task: 'academic', messages: [{ role: 'user', content: 'bad' }] }), /mistral request failed/);
assert.equal(calls.length, 1, 'non-retryable 400 must not cascade');
console.log('PASS non-retryable 400: fallback stopped');

failProvider = null;
failStatus = 503;
const specialistEnv = { ...env, TAVILY_API_KEY: 'test-tavily', EXA_API_KEY: 'test-exa', DEEPGRAM_API_KEY: 'test-deepgram', AI: { run: async () => ({ image: 'AQID' }) } };
const searchResult = await routeWebSearch(specialistEnv, { query: 'latest TRINEX', maxResults: 3, preferredProvider: 'tavily' });
assert.equal(searchResult.provider, 'tavily');
console.log('PASS web search: tavily primary');
failProvider = 'tavily';
resetProviderCircuitState();
const exaFallbackSearch = await routeWebSearch(specialistEnv, { query: 'latest TRINEX', maxResults: 3, preferredProvider: 'tavily' });
assert.equal(exaFallbackSearch.provider, 'exa');
console.log('PASS web search: tavily -> exa fallback');
failProvider = 'tavily';
failStatus = 403;
resetProviderCircuitState();
const forbiddenSearchFallback = await routeWebSearch(specialistEnv, { query: 'latest TRINEX', maxResults: 3, preferredProvider: 'tavily' });
assert.equal(forbiddenSearchFallback.provider, 'exa', 'Tavily 403 must fall back to Exa');
console.log('PASS web search: Tavily 403 -> Exa fallback');
failProvider = null;
failStatus = 503;
emptySearchProvider = 'tavily';
resetProviderCircuitState();
const emptySearchFallback = await routeWebSearch(specialistEnv, { query: 'latest TRINEX', maxResults: 3, preferredProvider: 'tavily' });
assert.equal(emptySearchFallback.provider, 'exa', 'empty Tavily results must fall back to Exa');
console.log('PASS web search: empty Tavily results -> Exa fallback');
emptySearchProvider = null;
failProvider = null;
resetProviderCircuitState();
const deepgramResult = await routeStt(specialistEnv, { file: new Uint8Array([1]), filename: 'a.mp3', contentType: 'audio/mpeg', language: 'ar' });
assert.equal(deepgramResult.provider, 'groq');
failProvider = 'groq';
const deepgramFallback = await routeStt(specialistEnv, { file: new Uint8Array([1]), filename: 'a.mp3', contentType: 'audio/mpeg', language: 'ar' });
assert.equal(deepgramFallback.provider, 'deepgram');
console.log('PASS stt: groq -> deepgram specialist');
failProvider = null; failProviders = new Set(); resetProviderCircuitState();
const imageResult = await routeImageGeneration(specialistEnv, { prompt: 'a simple academic illustration' });
assert.equal(imageResult.provider, 'cloudflare-ai');
console.log('PASS image generation: cloudflare-ai');
const fileResult = await routeFileAnalysis(specialistEnv, { file: new Uint8Array([1]), filename: 'note.txt', contentType: 'text/plain', prompt: 'summarize' });
assert.equal(fileResult.provider, 'gemini');
console.log('PASS file analysis: gemini primary');

calls = [];
failProvider = null;
failProviders = new Set();
resetProviderCircuitState();
const requestedModel = await routeText(env, { model: 'mistral-small-2603', messages: [{ role: 'user', content: 'model-select' }] });
assert.equal(requestedModel.provider, 'mistral', 'requested model should select matching provider');
assert.equal(calls.length, 1, 'requested model should use only its matching route');
console.log('PASS requested model: selected matching provider');

let unknownModelFailed = false;
try { await routeText(env, { model: 'not-configured-model', messages: [{ role: 'user', content: 'unknown' }] }); } catch (e) { unknownModelFailed = Number(e?.status) === 400; }
assert.equal(unknownModelFailed, true, 'unknown requested model should return 400');
console.log('PASS unknown requested model: rejected');

console.log('EINO PROVIDER MATRIX PASSED');
