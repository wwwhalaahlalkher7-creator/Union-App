/** OpenAI-compatible provider helpers shared by providers with compatible APIs. */
function endpoint(baseUrl, path) {
  const base = String(baseUrl || '').trim().replace(/\/+$/, '');
  if (!base) throw new Error('provider base URL is empty');
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
}

function providerError(provider, status, body) {
  const error = new Error(`${provider} request failed with status ${status}`);
  error.provider = provider;
  error.status = status;
  error.body = body;
  return error;
}

export async function openAiCompatibleChat({ provider, baseUrl, apiKey, model, messages, temperature = 0.4, maxTokens = 900, signal }) {
  if (!apiKey) throw new Error(`${provider} API key is empty`);
  const response = await fetch(endpoint(baseUrl, '/chat/completions'), {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({ model, messages, temperature, max_tokens: maxTokens }),
    signal,
  });
  if (!response.ok) throw providerError(provider, response.status, await response.text().catch(() => ''));
  const data = await response.json();
  const answer = data?.choices?.[0]?.message?.content;
  if (typeof answer !== 'string' || !answer.trim()) throw providerError(provider, response.status, 'empty answer');
  return { answer: answer.trim(), model: data?.model || model, usage: data?.usage || null, raw: data };
}

export async function openAiCompatibleVision({ provider, baseUrl, apiKey, model, imageDataUrl, prompt, signal }) {
  const messages = [{ role: 'user', content: [
    { type: 'text', text: prompt || 'حلل الصورة واشرح محتواها بدقة.' },
    { type: 'image_url', image_url: { url: imageDataUrl } },
  ] }];
  return openAiCompatibleChat({ provider, baseUrl, apiKey, model, messages, temperature: 0.2, maxTokens: 1200, signal });
}
