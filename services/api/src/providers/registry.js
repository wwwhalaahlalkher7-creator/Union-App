/** Capability-first provider and model registry. No provider is globally mandatory. */
export const EINO_CAPABILITIES = Object.freeze({ TEXT:'text', VISION:'vision', OCR:'ocr', STT:'stt', TTS:'tts', EMBEDDINGS:'embeddings' });

const bool = (v) => Boolean(String(v || '').trim());

export function getProviderRegistry(env = {}) {
  const free = bool(env.FREE_AI_BASE_URL) && bool(env.FREE_AI_API_KEY);
  const mistral = bool(env.MISTRAL_API_KEY);
  const groq = bool(env.GROQ_API_KEY);
  return Object.freeze({
    mistral: { id:'mistral', enabled:mistral, priority:10, capabilities:['text','vision','ocr','stt','tts'] },
    groq: { id:'groq', enabled:groq, priority:20, capabilities:['text','vision','stt','tts'] },
    'free.ai': { id:'free.ai', enabled:free, priority:30, capabilities:['text','vision','ocr','stt','tts'] },
  });
}

export function getModelRegistry(env = {}) {
  return {
    text: [
      { provider:'mistral', model:env.EINO_MISTRAL_TEXT_MODEL || 'mistral-small-2603', priority:10 },
      { provider:'groq', model:env.EINO_GROQ_TEXT_MODEL || 'openai/gpt-oss-120b', priority:20 },
      { provider:'free.ai', model:env.EINO_FREE_TEXT_MODEL || env.EINO_TEXT_MODEL || 'auto', priority:30 },
    ],
    vision: [
      { provider:'mistral', model:env.EINO_MISTRAL_VISION_MODEL || 'mistral-small-2603', priority:10 },
      { provider:'groq', model:env.EINO_GROQ_VISION_MODEL || 'qwen/qwen3.8-27b', priority:20 },
      { provider:'free.ai', model:env.EINO_FREE_VISION_MODEL || 'auto', priority:30 },
    ],
    ocr: [
      { provider:'mistral', model:env.EINO_MISTRAL_OCR_MODEL || 'mistral-ocr-latest', priority:10 },
      { provider:'free.ai', model:env.EINO_FREE_OCR_MODEL || 'got-ocr2', priority:30 },
    ],
    stt: [
      { provider:'groq', model:env.EINO_GROQ_STT_MODEL || 'whisper-large-v3-turbo', priority:10 },
      { provider:'mistral', model:env.EINO_MISTRAL_STT_MODEL || 'voxtral-mini-2602', priority:20 },
      { provider:'free.ai', model:env.EINO_FREE_STT_MODEL || 'whisper', priority:30 },
    ],
    tts: [
      { provider:'groq', model:env.EINO_GROQ_TTS_MODEL || 'canopylabs/orpheus-arabic-saudi', priority:10 },
      { provider:'mistral', model:env.EINO_MISTRAL_TTS_MODEL || 'voxtral-mini-tts-2603', priority:20 },
      { provider:'free.ai', model:env.EINO_FREE_TTS_MODEL || 'kokoro', priority:30 },
    ],
  };
}

export function getRoutesForCapability(env, capability) {
  const providers = getProviderRegistry(env); const models = getModelRegistry(env)[capability] || [];
  return models.filter((x) => providers[x.provider]?.enabled && providers[x.provider].capabilities.includes(capability)).sort((a,b)=>a.priority-b.priority);
}

export function getProvidersForCapability(env, capability) { return [...new Set(getRoutesForCapability(env, capability).map((x)=>x.provider))]; }
