import { getRoutesForCapability, EINO_CAPABILITIES } from './registry.js';
import { freeAiChat, } from './free_ai.js';
import { freeAiVision, freeAiOcr, freeAiStt, freeAiTts } from './free_ai_media.js';
import { mistralChat, mistralVision, mistralOcr, mistralStt, mistralTts } from './mistral.js';
import { groqChat, groqVision, groqStt, groqTts } from './groq.js';

function argsForFree(env, model) { return { baseUrl:env.FREE_AI_BASE_URL, apiKey:env.FREE_AI_API_KEY, model }; }

export async function routeText(env, args) {
  const allRoutes = getRoutesForCapability(env, EINO_CAPABILITIES.TEXT);
  const requestedModel = String(args?.model || '').trim();
  const routes = requestedModel ? allRoutes.filter((route) => route.model === requestedModel) : allRoutes;
  if (!routes.length) {
    const error = new Error(requestedModel ? `Requested text model is not configured: ${requestedModel}` : 'No text provider configured');
    error.status = requestedModel ? 400 : 503;
    throw error;
  }
  let last;
  for (const route of routes) {
    try {
      if (route.provider === 'mistral') return { ...(await mistralChat({ baseUrl:env.MISTRAL_BASE_URL, apiKey:env.MISTRAL_API_KEY, model:route.model, ...args })), provider:'mistral', route };
      if (route.provider === 'groq') return { ...(await groqChat({ baseUrl:env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey:env.GROQ_API_KEY, model:route.model, ...args })), provider:'groq', route };
      return { ...(await freeAiChat({ ...argsForFree(env, route.model), ...args })), provider:'free.ai', route };
    } catch (e) { last=e; if (![408,409,429,500,502,503,504].includes(Number(e?.status||502))) break; }
  }
  throw last || new Error('All text providers failed');
}

export async function routeVision(env, args) {
  const routes = getRoutesForCapability(env, EINO_CAPABILITIES.VISION); let last;
  for (const route of routes) { try {
    if (route.provider === 'mistral') return { ...(await mistralVision({ baseUrl:env.MISTRAL_BASE_URL, apiKey:env.MISTRAL_API_KEY, model:route.model, ...args })), provider:'mistral', route };
    if (route.provider === 'groq') return { ...(await groqVision({ baseUrl:env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1', apiKey:env.GROQ_API_KEY, model:route.model, ...args })), provider:'groq', route };
    const r=await freeAiVision({ ...argsForFree(env, route.model), ...args }); return { text:String(r?.text||r?.description||r?.caption||r?.result||'').trim(), raw:r, provider:'free.ai', route };
  } catch(e){ last=e; if(![408,409,429,500,502,503,504].includes(Number(e?.status||502))) break; }}
  throw last || new Error('All vision providers failed');
}

export async function routeOcr(env, args) {
  const routes=getRoutesForCapability(env,EINO_CAPABILITIES.OCR); let last;
  for(const route of routes){try{
    if(route.provider==='mistral') return {...(await mistralOcr({baseUrl:env.MISTRAL_BASE_URL,apiKey:env.MISTRAL_API_KEY,model:route.model,...args})),provider:'mistral',route};
    const r=await freeAiOcr({...argsForFree(env,route.model),...args}); return {text:String(r?.text||r?.content||r?.markdown||r?.result||'').trim(),raw:r,provider:'free.ai',route};
  }catch(e){last=e;if(![408,409,429,500,502,503,504].includes(Number(e?.status||502)))break;}}
  throw last||new Error('All OCR providers failed');
}

export async function routeStt(env,args){const routes=getRoutesForCapability(env,EINO_CAPABILITIES.STT);let last;for(const route of routes){try{if(route.provider==='groq')return{...(await groqStt({baseUrl:env.GROQ_BASE_URL||'https://api.groq.com/openai/v1',apiKey:env.GROQ_API_KEY,model:route.model,...args})),provider:'groq',route};if(route.provider==='mistral')return{...(await mistralStt({baseUrl:env.MISTRAL_BASE_URL,apiKey:env.MISTRAL_API_KEY,model:route.model,...args})),provider:'mistral',route};const r=await freeAiStt({...argsForFree(env,route.model),...args});return{text:String(r?.text||r?.transcript||r?.result||'').trim(),raw:r,provider:'free.ai',route};}catch(e){last=e;if(![408,409,429,500,502,503,504].includes(Number(e?.status||502)))break;}}throw last||new Error('All STT providers failed');}

export async function routeTts(env,args){const routes=getRoutesForCapability(env,EINO_CAPABILITIES.TTS);let last;for(const route of routes){try{if(route.provider==='groq')return{...(await groqTts({baseUrl:env.GROQ_BASE_URL||'https://api.groq.com/openai/v1',apiKey:env.GROQ_API_KEY,model:route.model,...args})),provider:'groq',route};if(route.provider==='mistral')return{...(await mistralTts({baseUrl:env.MISTRAL_BASE_URL,apiKey:env.MISTRAL_API_KEY,model:route.model,...args})),provider:'mistral',route};const r=await freeAiTts({...argsForFree(env,route.model),...args});return{audioUrl:r?.audio_url||r?.url||null,raw:r,provider:'free.ai',route};}catch(e){last=e;if(![408,409,429,500,502,503,504].includes(Number(e?.status||502)))break;}}throw last||new Error('All TTS providers failed');}
