/** Capability-first provider and model registry. No provider is globally mandatory. */
export const EINO_CAPABILITIES = Object.freeze({ TEXT:'text', VISION:'vision', OCR:'ocr', STT:'stt', TTS:'tts', EMBEDDINGS:'embeddings' });

const bool = (v) => Boolean(String(v || '').trim());

export function getProviderRegistry(env = {}) {
  const free = bool(env.FREE_AI_BASE_URL) && bool(env.FREE_AI_API_KEY);
  const mistral = bool(env.MISTRAL_API_KEY);
  const groq = bool(env.GROQ_API_KEY);
  const gemini = bool(env.GEMINI_API_KEY);
  const tavily = bool(env.TAVILY_API_KEY);
  const exa = bool(env.EXA_API_KEY);
  const deepgram = bool(env.DEEPGRAM_API_KEY);
  const cloudflareAi = Boolean(env.AI?.run);
  const mistralCapabilities = ['text','vision','ocr','stt'];
  if (mistral && bool(env.EINO_MISTRAL_TTS_VOICE_ID)) mistralCapabilities.push('tts');
  return Object.freeze({
    mistral: { id:'mistral', enabled:mistral, priority:10, capabilities:[...mistralCapabilities,'file-analysis'] },
    groq: { id:'groq', enabled:groq, priority:20, capabilities:['text','vision','stt','tts'] },
    gemini: { id:'gemini', enabled:gemini, priority:30, capabilities:['text','vision','stt','tts','file-analysis'] },
    'free.ai': { id:'free.ai', enabled:free, priority:40, capabilities:['text','vision','ocr','stt','tts'] },
    tavily: { id:'tavily', enabled:tavily, priority:10, capabilities:['web-search'] },
    exa: { id:'exa', enabled:exa, priority:20, capabilities:['web-search'] },
    deepgram: { id:'deepgram', enabled:deepgram, priority:15, capabilities:['stt'] },
    'cloudflare-ai': { id:'cloudflare-ai', enabled:cloudflareAi, priority:10, capabilities:['image-generation'] },
  });
}

export function getModelRegistry(env = {}) {
  return {
    text: [
      { provider:'mistral', model:env.EINO_MISTRAL_TEXT_MODEL || 'mistral-small-2603', priority:10 },
      { provider:'groq', model:env.EINO_GROQ_TEXT_MODEL || 'openai/gpt-oss-120b', priority:20 },
      { provider:'gemini', model:env.EINO_GEMINI_TEXT_MODEL || 'gemini-3.5-flash-lite', priority:30 },
      { provider:'free.ai', model:env.EINO_FREE_TEXT_MODEL || env.EINO_TEXT_MODEL || 'auto', priority:40 },
    ],
    vision: [
      { provider:'mistral', model:env.EINO_MISTRAL_VISION_MODEL || 'mistral-small-2603', priority:10 },
      { provider:'groq', model:env.EINO_GROQ_VISION_MODEL || 'qwen/qwen3.8-27b', priority:20 },
      { provider:'gemini', model:env.EINO_GEMINI_VISION_MODEL || 'gemini-3.5-flash-lite', priority:30 },
      { provider:'free.ai', model:env.EINO_FREE_VISION_MODEL || 'auto', priority:40 },
    ],
    ocr: [
      { provider:'mistral', model:env.EINO_MISTRAL_OCR_MODEL || 'mistral-ocr-latest', priority:10 },
      { provider:'free.ai', model:env.EINO_FREE_OCR_MODEL || 'got-ocr2', priority:30 },
    ],
    stt: [
      { provider:'groq', model:env.EINO_GROQ_STT_MODEL || 'whisper-large-v3-turbo', priority:10 },
      { provider:'deepgram', model:env.EINO_DEEPGRAM_STT_MODEL || 'nova-3', priority:15 },
      { provider:'mistral', model:env.EINO_MISTRAL_STT_MODEL || 'voxtral-mini-2602', priority:20 },
      { provider:'gemini', model:env.EINO_GEMINI_STT_MODEL || 'gemini-3.5-transcribe', priority:30 },
      { provider:'free.ai', model:env.EINO_FREE_STT_MODEL || 'whisper', priority:40 },
    ],
    'web-search': [
      { provider:'tavily', model:env.EINO_TAVILY_SEARCH_MODEL || 'search', priority:10 },
      { provider:'exa', model:env.EINO_EXA_SEARCH_MODEL || 'search', priority:20 },
    ],
    'image-generation': [
      { provider:'cloudflare-ai', model:env.EINO_CLOUDFLARE_IMAGE_MODEL || '@cf/black-forest-labs/flux-1-schnell', priority:10 },
    ],
    'file-analysis': [
      { provider:'gemini', model:env.EINO_GEMINI_FILE_MODEL || env.EINO_GEMINI_VISION_MODEL || 'gemini-3.5-flash-lite', priority:10 },
      { provider:'mistral', model:env.EINO_MISTRAL_FILE_MODEL || env.EINO_MISTRAL_VISION_MODEL || 'mistral-small-2603', priority:20 },
    ],
    tts: [
      { provider:'groq', model:env.EINO_GROQ_TTS_MODEL || 'canopylabs/orpheus-arabic-saudi', priority:10 },
      { provider:'groq', model:'canopylabs/orpheus-v1-english', priority:11 },
      { provider:'mistral', model:env.EINO_MISTRAL_TTS_MODEL || 'voxtral-mini-tts-2603', priority:20 },
      { provider:'gemini', model:env.EINO_GEMINI_TTS_MODEL || 'gemini-3.8-flash-tts', priority:30 },
      { provider:'free.ai', model:env.EINO_FREE_TTS_MODEL || 'kokoro', priority:40 },
    ],
  };
}

export function getRoutesForCapability(env, capability) {
  const providers = getProviderRegistry(env); const models = getModelRegistry(env)[capability] || [];
  return models.filter((x) => providers[x.provider]?.enabled && providers[x.provider].capabilities.includes(capability)).sort((a,b)=>a.priority-b.priority);
}

export function getProvidersForCapability(env, capability) { return [...new Set(getRoutesForCapability(env, capability).map((x)=>x.provider))]; }
