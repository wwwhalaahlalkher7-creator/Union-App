import { getRoutesForCapability, EINO_CAPABILITIES } from './registry.js';
import { freeAiChat } from './free_ai.js';
import { freeAiVision, freeAiOcr, freeAiStt, freeAiTts } from './free_ai_media.js';
import { mistralChat, mistralVision, mistralOcr, mistralStt, mistralTts } from './mistral.js';
import { groqChat, groqVision, groqStt, groqTts } from './groq.js';
import { geminiChat, geminiVision, geminiStt, geminiTts, geminiFileAnalysis } from './gemini.js';
import { tavilySearch, exaSearch, formatSearchContext } from './search.js';
import { deepgramStt } from './deepgram.js';
import { cloudflareImage } from './cloudflare_ai.js';
import { textRouteOrder } from './task_router.js';

const CIRCUIT_FAILURE_THRESHOLD = 3;
const CIRCUIT_COOLDOWN_MS = 30_000;
const MAX_PROVIDER_ATTEMPTS = 2;
const RETRYABLE = new Set([408, 409, 425, 429, 500, 502, 503, 504]);
const circuitState = new Map();

function argsForFree(env, model) { return { baseUrl: env.FREE_AI_BASE_URL, apiKey: env.FREE_AI_API_KEY, model }; }

function keyFor(route) { return `${route.provider}:${route.model}`; }
function now() { return Date.now(); }

function circuitOpen(route) {
  const state = circuitState.get(keyFor(route));
  if (!state || state.failures < CIRCUIT_FAILURE_THRESHOLD) return false;
  if (now() - state.openedAt >= CIRCUIT_COOLDOWN_MS) return false;
  return true;
}

function recordSuccess(route) { circuitState.delete(keyFor(route)); }
export function resetProviderCircuitState() {
  circuitState.clear();
}

function recordFailure(route) {
  const key = keyFor(route);
  const state = circuitState.get(key) || { failures: 0, openedAt: 0 };
  state.failures += 1;
  if (state.failures >= CIRCUIT_FAILURE_THRESHOLD) state.openedAt = now();
  circuitState.set(key, state);
}

function retryAfterMs(error) {
  const value = Number(error?.retryAfterMs);
  return Number.isFinite(value) && value > 0 ? Math.min(value, 5000) : 0;
}

function backoffMs(attempt, error) {
  const hinted = retryAfterMs(error);
  if (hinted) return hinted;
  return Math.min(1200, 250 * (2 ** attempt));
}

function retryable(error) { return RETRYABLE.has(Number(error?.status || 0)) || error?.name === 'AbortError'; }

async function sleep(ms) { if (ms > 0) await new Promise((resolve) => setTimeout(resolve, ms)); }

async function runRoute(route, operation) {
  if (circuitOpen(route)) {
    const error = new Error(`Circuit open for ${keyFor(route)}`);
    error.status = 503; error.code = 'CIRCUIT_OPEN';
    throw error;
  }
  let last;
  for (let attempt = 0; attempt < MAX_PROVIDER_ATTEMPTS; attempt += 1) {
    try {
      const result = await operation();
      recordSuccess(route);
      return normalizeResult(result, route);
    } catch (error) {
      last = error;
      if (!retryable(error) || attempt === MAX_PROVIDER_ATTEMPTS - 1) break;
      await sleep(backoffMs(attempt, error));
    }
  }
  recordFailure(route);
  throw last || new Error(`Provider failed: ${keyFor(route)}`);
}

function normalizeResult(result, route) {
  const value = result || {};
  return {
    ...value,
    provider: route.provider,
    route,
    model: value.model || route.model,
    reliability: { provider: route.provider, model: route.model, fallback: false },
  };
}

async function routeCapability(env, capability, requestedModel, operationFactory, label, routeFilter = null) {
  const allRoutes = getRoutesForCapability(env, capability);
  const eligibleRoutes = routeFilter ? allRoutes.filter(routeFilter) : allRoutes;
  const routes = requestedModel ? eligibleRoutes.filter((route) => route.model === requestedModel) : eligibleRoutes;
  if (!routes.length) {
    const error = new Error(requestedModel ? `Requested ${label} model is not configured: ${requestedModel}` : `No ${label} provider configured`);
    error.status = requestedModel ? 400 : 503;
    throw error;
  }
  let last;
  let skipped = 0;
  for (const route of routes) {
    try {
      const result = await runRoute(route, operationFactory(route));
      result.reliability = {
        provider: route.provider,
        model: route.model,
        fallback: route.priority !== routes[0]?.priority,
        candidates: routes.map((candidate) => `${candidate.provider}:${candidate.model}`),
        skippedCircuits: skipped,
      };
      return result;
    } catch (error) {
      last = error;
      if (error?.code === 'CIRCUIT_OPEN') { skipped += 1; continue; }
      if (!retryable(error)) break;
    }
  }
  throw last || new Error(`All ${label} providers failed`);
}

export async function routeText(env, args) {
  const requestedModel = String(args?.model || '').trim();
  const task = String(args?.task || 'chat').trim();
  const order = textRouteOrder(task);
  const routes = getRoutesForCapability(env, EINO_CAPABILITIES.TEXT)
    .filter((route) => requestedModel ? route.model === requestedModel : order.includes(route.provider))
    .sort((a, b) => requestedModel ? a.priority - b.priority : (order.indexOf(a.provider) - order.indexOf(b.provider)) || (a.priority - b.priority));
  if (!routes.length) {
    const e = new Error(requestedModel ? `Requested text model is not configured: ${requestedModel}` : 'No text provider configured');
    e.status = requestedModel ? 400 : 503;
    throw e;
  }
  let last;
  for (const route of routes) {
    try {
      const result = await runRoute(route, async () => {
        if (route.provider === 'mistral') return mistralChat({ baseUrl: `${String(env.EINO_MISTRAL_BASE_URL || 'https://api.mistral.ai').replace(/\/+$/, '')}/v1`, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
        if (route.provider === 'groq') return groqChat({ baseUrl: env.EINO_GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
        if (route.provider === 'gemini') return geminiChat({ baseUrl: env.EINO_GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta', apiKey: env.GEMINI_API_KEY, model: route.model, ...args });
        return freeAiChat({ ...argsForFree(env, route.model), ...args });
      });
      result.reliability = { ...result.reliability, task, taskOrder: order, fallback: route !== routes[0] };
      return result;
    } catch (error) {
      last = error;
      if (error?.code === 'CIRCUIT_OPEN' || retryable(error)) continue;
      break;
    }
  }
  throw last || Object.assign(new Error('All text providers failed'), { status: 503 });
}

export async function routeVision(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.VISION, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'mistral') return mistralVision({ baseUrl: `${String(env.EINO_MISTRAL_BASE_URL || 'https://api.mistral.ai').replace(/\/+$/, '')}/v1`, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    if (route.provider === 'groq') return groqVision({ baseUrl: env.EINO_GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
    if (route.provider === 'gemini') return geminiVision({ baseUrl: env.EINO_GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta', apiKey: env.GEMINI_API_KEY, model: route.model, ...args });
    const result = await freeAiVision({ ...argsForFree(env, route.model), ...args });
    return { text: String(result?.text || result?.description || result?.caption || result?.result || '').trim(), raw: result };
  }, 'vision');
}

export async function routeOcr(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.OCR, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'mistral') return mistralOcr({ baseUrl: env.EINO_MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    const result = await freeAiOcr({ ...argsForFree(env, route.model), ...args });
    return { text: String(result?.text || result?.content || result?.markdown || result?.result || '').trim(), raw: result };
  }, 'ocr');
}

export async function routeStt(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.STT, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'groq') return groqStt({ baseUrl: env.EINO_GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
    if (route.provider === 'deepgram') return deepgramStt({ apiKey: env.DEEPGRAM_API_KEY, model: route.model, ...args });
    if (route.provider === 'mistral') return mistralStt({ baseUrl: env.EINO_MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    if (route.provider === 'gemini') return geminiStt({ baseUrl: env.EINO_GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta', apiKey: env.GEMINI_API_KEY, model: route.model, ...args });
    const result = await freeAiStt({ ...argsForFree(env, route.model), ...args });
    return { text: String(result?.text || result?.transcript || result?.result || '').trim(), raw: result };
  }, 'stt');
}

function hasArabicText(text) {
  return /[\u0600-\u06FF]/.test(String(text || ''));
}

export async function routeTts(env, args) {
  const requestedModel = String(args?.model || '').trim();
  const text = String(args?.text || '').trim();
  const englishModel = 'canopylabs/orpheus-v1-english';
  const arabicModel = env.EINO_GROQ_TTS_MODEL || 'canopylabs/orpheus-arabic-saudi';
  const autoModel = requestedModel || (hasArabicText(text) ? arabicModel : englishModel);
  const voice = String(args?.voice || '').trim() || (autoModel === englishModel ? 'hannah' : 'noura');
  const routeFilter = requestedModel ? null : (route) => route.provider !== 'groq' || route.model === autoModel;
  return routeCapability(env, EINO_CAPABILITIES.TTS, requestedModel, (route) => async () => {
    const routeVoice = args?.voice || (route.provider === 'groq' ? (route.model === englishModel ? 'hannah' : 'noura') : route.provider === 'gemini' ? 'Kore' : undefined);
    const routeArgs = { ...args, model: route.model, ...(routeVoice ? { voice: routeVoice } : {}) };
    if (route.provider === 'groq') return groqTts({ baseUrl: env.EINO_GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...routeArgs });
    if (route.provider === 'mistral') return mistralTts({ baseUrl: env.EINO_MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, voiceId: env.EINO_MISTRAL_TTS_VOICE_ID, ...routeArgs });
    if (route.provider === 'gemini') return geminiTts({ baseUrl: env.EINO_GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta', apiKey: env.GEMINI_API_KEY, model: route.model, voice: routeVoice || 'Kore', ...routeArgs });
    const result = await freeAiTts({ ...argsForFree(env, route.model), ...routeArgs });
    return { audioUrl: result?.audio_url || result?.url || null, audioBase64: result?.audioBase64 || result?.audio_base64 || null, contentType: result?.contentType || result?.content_type || 'audio/mpeg', raw: result };
  }, 'tts', routeFilter);
}


export async function routeWebSearch(env, args) {
  const preferred = String(args?.preferredProvider || '').trim();
  const routes = getRoutesForCapability(env, 'web-search').sort((a, b) => {
    if (preferred) return (a.provider === preferred ? -1 : 1) - (b.provider === preferred ? -1 : 1) || a.priority - b.priority;
    return a.priority - b.priority;
  });
  if (!routes.length) throw Object.assign(new Error('No web search provider configured'), { status: 503 });
  let last;
  for (const route of routes) {
    try {
      return await runRoute(route, async () => {
        if (route.provider === 'tavily') return tavilySearch({ apiKey: env.TAVILY_API_KEY, query: args.query, maxResults: args.maxResults, searchDepth: args.searchDepth, signal: args.signal });
        if (route.provider === 'exa') return exaSearch({ apiKey: env.EXA_API_KEY, query: args.query, maxResults: args.maxResults, signal: args.signal });
        throw Object.assign(new Error(`Unsupported search provider ${route.provider}`), { status: 503 });
      });
    } catch (error) {
      last = error;
      if (error?.code === 'CIRCUIT_OPEN' || retryable(error)) continue;
      break;
    }
  }
  throw last || Object.assign(new Error('All web search providers failed'), { status: 503 });
}


export async function routeFileAnalysis(env, args) {
  const routes = getRoutesForCapability(env, 'file-analysis');
  if (!routes.length) throw Object.assign(new Error('No file analysis provider configured'), { status: 503 });
  let last;
  for (const route of routes) {
    try {
      const result = await runRoute(route, async () => {
        if (route.provider === 'gemini') return geminiFileAnalysis({ baseUrl: env.EINO_GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta', apiKey: env.GEMINI_API_KEY, model: route.model, ...args });
        if (route.provider === 'mistral') {
          const extracted = await mistralOcr({ baseUrl: env.EINO_MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: env.EINO_MISTRAL_OCR_MODEL || 'mistral-ocr-latest', ...args });
          const text = String(extracted?.text || extracted?.content || extracted?.markdown || '').trim();
          if (!text) throw Object.assign(new Error('Mistral OCR returned no text'), { status: 502 });
          return mistralChat({ baseUrl: `${String(env.EINO_MISTRAL_BASE_URL || 'https://api.mistral.ai').replace(/\/+$/, '')}/v1`, apiKey: env.MISTRAL_API_KEY, model: route.model, messages: [{ role: 'system', content: 'حلل محتوى الملف المستخرج بدقة ولا تضف معلومات غير موجودة.' }, { role: 'user', content: `${args.prompt || 'حلل الملف'}\n\nمحتوى الملف:\n${text.slice(0, 18000)}` }], maxTokens: 1800, signal: args.signal });
        }
        throw Object.assign(new Error(`Unsupported file analysis provider ${route.provider}`), { status: 503 });
      });
      return result;
    } catch (error) { last = error; if (error?.code === 'CIRCUIT_OPEN' || retryable(error)) continue; break; }
  }
  throw last || Object.assign(new Error('All file analysis providers failed'), { status: 503 });
}

export async function routeImageGeneration(env, args) {
  return routeCapability(env, 'image-generation', '', (route) => async () => {
    if (route.provider === 'cloudflare-ai') return cloudflareImage({ ai: env.AI, model: route.model, ...args });
    throw Object.assign(new Error(`Unsupported image provider ${route.provider}`), { status: 503 });
  }, 'image-generation');
}

export { formatSearchContext };
