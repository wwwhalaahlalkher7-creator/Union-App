/**
 * Free.ai provider adapter.
 *
 * Eino's public API must not depend on provider-specific request details.
 * Keep Free.ai URL/auth/retry/response handling in this module so the provider
 * can be replaced without changing the Eino route or Flutter client.
 */

function resolveChatEndpoint(baseUrl) {
  const base = String(baseUrl || '').trim().replace(/\/+$/, '');
  if (!base) throw new Error('FREE_AI_BASE_URL is empty');
  return /\/v1$/i.test(base) ? `${base}/chat/` : `${base}/v1/chat/`;
}

function providerError(status, body) {
  const error = new Error(`Free.ai request failed with status ${status}`);
  error.provider = 'free.ai';
  error.status = status;
  error.body = body;
  return error;
}

export async function freeAiChat({ baseUrl, apiKey, model, messages, temperature = 0.4, maxTokens = 900, signal }) {
  if (!apiKey) throw new Error('FREE_AI_API_KEY is empty');

  const endpoint = resolveChatEndpoint(baseUrl);
  const requestBody = JSON.stringify({
    model,
    messages,
    temperature,
    max_tokens: maxTokens,
  });

  let response;
  let lastBody = '';
  for (let attempt = 0; attempt < 2; attempt++) {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${apiKey}`,
      },
      body: requestBody,
      signal,
    });

    if (response.ok) break;

    lastBody = await response.text().catch(() => '');
    if (![502, 503, 504].includes(response.status) || attempt === 1) {
      throw providerError(response.status, lastBody);
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }

  const data = await response.json();
  const answer = data?.choices?.[0]?.message?.content;
  if (typeof answer !== 'string' || !answer.trim()) {
    const error = new Error('Free.ai returned an empty answer');
    error.provider = 'free.ai';
    error.status = response.status;
    error.body = data;
    throw error;
  }

  return {
    answer: answer.trim(),
    model: data?.free_ai_usage?.model || model,
    usage: data?.free_ai_usage || null,
    raw: data,
  };
}
