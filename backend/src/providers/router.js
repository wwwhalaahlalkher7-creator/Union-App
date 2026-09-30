import { getRoutesForCapability, EINO_CAPABILITIES } from './registry.js';
import { freeAiChat } from './free_ai.js';
import { freeAiVision, freeAiOcr, freeAiStt, freeAiTts } from './free_ai_media.js';
import { mistralChat, mistralVision, mistralOcr, mistralStt, mistralTts } from './mistral.js';
import { groqChat, groqVision, groqStt, groqTts } from './groq.js';

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

async function routeCapability(env, capability, requestedModel, operationFactory, label) {
  const allRoutes = getRoutesForCapability(env, capability);
  const routes = requestedModel ? allRoutes.filter((route) => route.model === requestedModel) : allRoutes;
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
  return routeCapability(env, EINO_CAPABILITIES.TEXT, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'mistral') return mistralChat({ baseUrl: env.MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    if (route.provider === 'groq') return groqChat({ baseUrl: env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
    return freeAiChat({ ...argsForFree(env, route.model), ...args });
  }, 'text');
}

export async function routeVision(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.VISION, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'mistral') return mistralVision({ baseUrl: env.MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    if (route.provider === 'groq') return groqVision({ baseUrl: env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
    const result = await freeAiVision({ ...argsForFree(env, route.model), ...args });
    return { text: String(result?.text || result?.description || result?.caption || result?.result || '').trim(), raw: result };
  }, 'vision');
}

export async function routeOcr(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.OCR, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'mistral') return mistralOcr({ baseUrl: env.MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    const result = await freeAiOcr({ ...argsForFree(env, route.model), ...args });
    return { text: String(result?.text || result?.content || result?.markdown || result?.result || '').trim(), raw: result };
  }, 'ocr');
}

export async function routeStt(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.STT, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'groq') return groqStt({ baseUrl: env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
    if (route.provider === 'mistral') return mistralStt({ baseUrl: env.MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    const result = await freeAiStt({ ...argsForFree(env, route.model), ...args });
    return { text: String(result?.text || result?.transcript || result?.result || '').trim(), raw: result };
  }, 'stt');
}

export async function routeTts(env, args) {
  return routeCapability(env, EINO_CAPABILITIES.TTS, String(args?.model || '').trim(), (route) => async () => {
    if (route.provider === 'groq') return groqTts({ baseUrl: env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey: env.GROQ_API_KEY, model: route.model, ...args });
    if (route.provider === 'mistral') return mistralTts({ baseUrl: env.MISTRAL_BASE_URL, apiKey: env.MISTRAL_API_KEY, model: route.model, ...args });
    const result = await freeAiTts({ ...argsForFree(env, route.model), ...args });
    return { audioUrl: result?.audio_url || result?.url || null, raw: result };
  }, 'tts');
}
