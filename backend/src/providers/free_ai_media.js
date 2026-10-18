/** Free.ai media adapter. Provider-specific media contracts live here. */

function endpoint(baseUrl, path) {
  const base = String(baseUrl || '').trim().replace(/\/+$/, '');
  if (!base) throw new Error('FREE_AI_BASE_URL is empty');
  return /\/v1$/i.test(base) ? `${base}/${path.replace(/^\//, '')}` : `${base}/v1/${path.replace(/^\//, '')}`;
}

function providerError(status, body) {
  const error = new Error(`Free.ai request failed with status ${status}`);
  error.provider = 'free.ai';
  error.status = status;
  error.body = body;
  return error;
}

async function postJson({ baseUrl, apiKey, path, body, signal }) {
  if (!apiKey) throw new Error('FREE_AI_API_KEY is empty');
  const response = await fetch(endpoint(baseUrl, path), {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` },
    body: JSON.stringify(body),
    signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  return response.json();
}

async function postMultipart({ baseUrl, apiKey, path, fieldName, file, filename, contentType, fields = {}, signal }) {
  if (!apiKey) throw new Error('FREE_AI_API_KEY is empty');
  const form = new FormData();
  for (const [key, value] of Object.entries(fields)) form.append(key, String(value));
  form.append(fieldName, new File([file], filename || 'upload', { type: contentType || 'application/octet-stream' }));
  const response = await fetch(endpoint(baseUrl, path), {
    method: 'POST',
    headers: { authorization: `Bearer ${apiKey}` },
    body: form,
    signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  return response.json();
}

export async function freeAiVision({ baseUrl, apiKey, imageDataUrl, mode = 'describe', model, signal }) {
  return postJson({
    baseUrl, apiKey, path: 'image/describe/', signal,
    body: { image: imageDataUrl, mode, ...(model ? { model } : {}) },
  });
}

export async function freeAiOcr({ baseUrl, apiKey, file, filename, contentType, model = 'got-ocr2', signal }) {
  return postMultipart({
    baseUrl, apiKey, path: 'ocr/', fieldName: 'image', file, filename, contentType,
    fields: { model }, signal,
  });
}

export async function freeAiStt({ baseUrl, apiKey, file, filename, contentType, model = 'whisper', language = 'auto', signal }) {
  return postMultipart({
    baseUrl, apiKey, path: 'stt/', fieldName: 'file', file, filename, contentType,
    fields: { model, language }, signal,
  });
}

export async function freeAiTts({ baseUrl, apiKey, text, model = 'kokoro', voice = 'af_heart', signal }) {
  return postJson({ baseUrl, apiKey, path: 'tts/', body: { text, model, voice }, signal });
}
