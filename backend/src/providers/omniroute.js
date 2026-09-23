/**
 * Leo OmniRoute adapter for Eino.
 *
 * Accepts either a full OpenAI-compatible /chat/completions URL or an
 * OmniRoute /v1 base URL. Provider details stay behind this adapter so Eino
 * itself remains provider-agnostic.
 */

function resolveChatEndpoint(baseUrl) {
  const base = String(baseUrl || '').trim().replace(/\/+$/, '');
  if (!base) throw new Error('OMNIROUTE_BASE_URL is empty');
  if (/\/chat\/completions$/i.test(base)) return base;
  if (/\/v1$/i.test(base)) return `${base}/chat/completions`;
  return `${base}/v1/chat/completions`;
}

function providerError(status, body) {
  const error = new Error(`Leo OmniRoute request failed with status ${status}`);
  error.provider = 'leo-omniroute';
  error.status = status;
  error.body = body;
  return error;
}

function isModelSelectionError(status, body) {
  if (![400, 404].includes(Number(status))) return false;
  const text = typeof body === 'string' ? body.toLowerCase() : JSON.stringify(body || '').toLowerCase();
  return /model|alias|auto/.test(text);
}

async function listModels(baseUrl, apiKey, signal) {
  const base = String(baseUrl || '').trim().replace(/\/+$/, '');
  const endpoint = /\/v1$/i.test(base) ? `${base}/models` : `${base}/v1/models`;
  const response = await fetch(endpoint, {
    method: 'GET',
    headers: { accept: 'application/json', ...(apiKey ? { authorization: `Bearer ${apiKey}` } : {}) },
    signal,
  });
  const body = await response.text().catch(() => '');
  if (!response.ok) throw providerError(response.status, body);
  const data = JSON.parse(body);
  return Array.isArray(data?.data) ? data.data : [];
}

function pickChatModel(models) {
  const candidates = models
    .map((item) => ({ id: String(item?.id || '').trim(), type: String(item?.type || item?.object || '').toLowerCase() }))
    .filter((item) => item.id && !/embedding|embed|image|vision|audio|tts|stt/.test(`${item.id} ${item.type}`));
  return candidates[0]?.id || '';
}

function extractAnswer(data) {
  const value = data?.choices?.[0]?.message?.content;
  if (typeof value === 'string') return value.trim();
  if (Array.isArray(value)) {
    return value.map((part) => typeof part === 'string' ? part : String(part?.text || part?.content || '')).join('').trim();
  }
  return '';
}

export async function omniRouteChat({ baseUrl, apiKey, model, messages, temperature = 0.4, maxTokens = 900, signal }) {
  const endpoint = resolveChatEndpoint(baseUrl);
  const headers = { 'content-type': 'application/json', accept: 'application/json' };
  if (apiKey) headers.authorization = `Bearer ${apiKey}`;


  const send = async (requestModel) => {
    const body = JSON.stringify({
      model: requestModel,
      messages,
      temperature,
      max_tokens: maxTokens,
      stream: false,
    });
    let response;
    let lastBody = '';
    for (let attempt = 0; attempt < 2; attempt++) {
      response = await fetch(endpoint, { method: 'POST', headers, body, signal });
      if (response.ok) break;
      lastBody = await response.text().catch(() => '');
      if (![502, 503, 504].includes(response.status) || attempt === 1) {
        throw providerError(response.status, lastBody);
      }
      await new Promise((resolve) => setTimeout(resolve, 350));
    }
    const data = await response.json().catch(() => null);
    const answer = extractAnswer(data);
    if (!answer) throw providerError(response.status, data || lastBody || 'empty response');
    return { answer, model: data?.model || requestModel, usage: data?.usage || null, raw: data };
  };

  try {
    return await send(model);
  } catch (error) {
    // Some OmniRoute builds expose automatic routing through the dashboard but
    // do not expose the `auto` alias on the OpenAI-compatible endpoint. If that
    // is the only incompatibility, resolve a real chat model and retry once.
    if (String(model).toLowerCase() === 'auto' && isModelSelectionError(error?.status, error?.body)) {
      const models = await listModels(baseUrl, apiKey, signal);
      const fallbackModel = pickChatModel(models);
      if (fallbackModel) return send(fallbackModel);
    }
    throw error;
  }
}
