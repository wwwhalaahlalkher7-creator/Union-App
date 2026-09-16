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

  const requestBody = JSON.stringify({
    model,
    messages,
    temperature,
    max_tokens: maxTokens,
    stream: false,
  });

  let response;
  let lastBody = '';
  for (let attempt = 0; attempt < 2; attempt++) {
    response = await fetch(endpoint, { method: 'POST', headers, body: requestBody, signal });
    if (response.ok) break;
    lastBody = await response.text().catch(() => '');
    if (![502, 503, 504].includes(response.status) || attempt === 1) {
      throw providerError(response.status, lastBody);
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }

  const data = await response.json().catch(() => null);
  const answer = extractAnswer(data);
  if (!answer) {
    throw providerError(response.status, data || lastBody || 'empty response');
  }

  return {
    answer,
    model: data?.model || model,
    usage: data?.usage || null,
    raw: data,
  };
}
