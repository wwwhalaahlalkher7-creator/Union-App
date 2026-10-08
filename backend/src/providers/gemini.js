/** Google Gemini provider adapter. Free-tier-first REST integration. */

export const GEMINI_DEFAULTS = Object.freeze({
  text: 'gemini-3.5-flash-lite',
  vision: 'gemini-3.5-flash-lite',
  stt: 'gemini-3.5-transcribe',
  tts: 'gemini-3.8-flash-lite-tts',
});

function providerError(status, body, headers = null) {
  const error = new Error(`gemini request failed with status ${status}`);
  error.provider = 'gemini'; error.status = status; error.body = body;
  const retryAfter = headers?.get?.('retry-after');
  if (retryAfter) {
    const seconds = Number(retryAfter);
    const date = Number.isFinite(seconds) ? seconds * 1000 : Math.max(0, Date.parse(retryAfter) - Date.now());
    if (Number.isFinite(date) && date > 0) error.retryAfterMs = date;
  }
  return error;
}

function endpoint(baseUrl, model, suffix = 'generateContent') {
  const base = String(baseUrl || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/+$/, '');
  return `${base}/models/${encodeURIComponent(model)}:${suffix}`;
}

function extractText(data) {
  return (data?.candidates || [])
    .flatMap((candidate) => candidate?.content?.parts || [])
    .map((part) => String(part?.text || ''))
    .filter(Boolean)
    .join('')
    .trim();
}

function toGeminiMessages(messages = []) {
  let system = '';
  const contents = [];
  for (const message of messages) {
    const role = message?.role === 'assistant' ? 'model' : message?.role === 'system' ? 'system' : 'user';
    const text = typeof message?.content === 'string' ? message.content : JSON.stringify(message?.content ?? '');
    if (role === 'system') { system += `${system ? '\n' : ''}${text}`; continue; }
    contents.push({ role, parts: [{ text }] });
  }
  return { system, contents };
}

async function generate({ baseUrl, apiKey, model, body, signal }) {
  if (!apiKey) throw new Error('GEMINI_API_KEY is empty');
  const response = await fetch(endpoint(baseUrl, model), {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify(body),
    signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''), response.headers);
  const data = await response.json();
  return { data, status: response.status };
}

export async function geminiChat({ baseUrl, apiKey, model = GEMINI_DEFAULTS.text, messages, temperature = 0.4, maxTokens = 900, signal }) {
  const mapped = toGeminiMessages(messages);
  const body = {
    contents: mapped.contents,
    generationConfig: { temperature, maxOutputTokens: maxTokens },
    ...(mapped.system ? { systemInstruction: { parts: [{ text: mapped.system }] } } : {}),
  };
  const { data } = await generate({ baseUrl, apiKey, model, body, signal });
  const answer = extractText(data);
  if (!answer) throw providerError(200, 'empty answer');
  return { answer, model: data?.modelVersion || model, usage: data?.usageMetadata || null, raw: data };
}

function parseDataUrl(dataUrl) {
  const match = String(dataUrl || '').match(/^data:([^;,]+);base64,(.+)$/s);
  if (!match) return null;
  return { mimeType: match[1], data: match[2] };
}

export async function geminiVision({ baseUrl, apiKey, model = GEMINI_DEFAULTS.vision, imageDataUrl, prompt, signal }) {
  const image = parseDataUrl(imageDataUrl);
  if (!image) throw new Error('Gemini vision requires a base64 data URL');
  const body = {
    contents: [{ role: 'user', parts: [
      { text: prompt || 'حلل الصورة واشرح محتواها بدقة.' },
      { inlineData: { mimeType: image.mimeType, data: image.data } },
    ] }],
    generationConfig: { temperature: 0.2, maxOutputTokens: 1200 },
  };
  const { data } = await generate({ baseUrl, apiKey, model, body, signal });
  const answer = extractText(data);
  if (!answer) throw providerError(200, 'empty vision answer');
  return { answer, model: data?.modelVersion || model, usage: data?.usageMetadata || null, raw: data };
}


async function uploadFile({ baseUrl, apiKey, file, filename, contentType, signal }) {
  const base = String(baseUrl || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/+$/, '');
  const bytes = file instanceof ArrayBuffer ? new Uint8Array(file) : new Uint8Array(file || []);
  const mimeType = contentType || 'application/octet-stream';
  const start = await fetch(`${base.replace('/v1beta', '')}/upload/v1beta/files`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-goog-api-key': apiKey,
      'x-goog-upload-protocol': 'resumable',
      'x-goog-upload-command': 'start',
      'x-goog-upload-header-content-length': String(bytes.byteLength),
      'x-goog-upload-header-content-type': mimeType,
    },
    body: JSON.stringify({ file: { display_name: filename || 'audio' } }),
    signal,
  });
  if (!start.ok) throw providerError(start.status, await start.text().catch(() => ''), start.headers);
  const uploadUrl = start.headers.get('x-goog-upload-url');
  if (!uploadUrl) throw providerError(200, 'Gemini Files API did not return upload URL');
  const upload = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      'content-length': String(bytes.byteLength),
      'x-goog-upload-offset': '0',
      'x-goog-upload-command': 'upload, finalize',
      'content-type': mimeType,
    },
    body: bytes,
    signal,
  });
  if (!upload.ok) throw providerError(upload.status, await upload.text().catch(() => ''), upload.headers);
  const data = await upload.json();
  const fileInfo = data?.file || data;
  if (!fileInfo?.uri) throw providerError(200, 'Gemini Files API returned no file URI');
  return { uri: fileInfo.uri, mimeType: fileInfo.mimeType || mimeType };
}

export async function geminiStt({ baseUrl, apiKey, model = GEMINI_DEFAULTS.stt, file, filename, contentType, language, signal }) {
  if (!apiKey) throw new Error('GEMINI_API_KEY is empty');
  const uploaded = await uploadFile({ baseUrl, apiKey, file, filename, contentType, signal });
  const languageCodes = language && language !== 'auto' ? [language === 'ar' ? 'ar' : language === 'fr' ? 'fr' : 'en'] : [];
  const base = String(baseUrl || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/+$/, '');
  const response = await fetch(`${base}/interactions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      model,
      input: [{ type: 'audio', uri: uploaded.uri, mime_type: uploaded.mimeType }],
      generation_config: { transcription_config: { mode: 'smart', language_codes: languageCodes } },
    }),
    signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''), response.headers);
  const data = await response.json();
  const text = String(data?.output_text || data?.outputs?.filter((x) => x?.type === 'text').map((x) => x?.text || '').join('') || '').trim();
  if (!text) throw providerError(200, 'empty transcription');
  return { text, model, raw: data };
}

export async function geminiTts({ baseUrl, apiKey, model = GEMINI_DEFAULTS.tts, text, voice = 'Kore', signal }) {
  if (!apiKey) throw new Error('GEMINI_API_KEY is empty');
  const base = String(baseUrl || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/+$/, '');
  const response = await fetch(`${base}/interactions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      model,
      input: [{ type: 'user_input', content: [{ type: 'text', text: String(text || '') }] }],
      response_format: { type: 'audio', mime_type: 'audio/wav', sample_rate: 24000 },
      generation_config: { speech_config: [{ voice }] },
    }),
    signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''), response.headers);
  const data = await response.json();
  const audioBase64 = data?.output_audio?.data || [...(data?.steps || [])].reverse().find((step) => step?.type === 'model_output')?.content?.find((part) => part?.type === 'audio')?.data;
  if (!audioBase64) throw providerError(200, 'empty audio output');
  return { audioBase64, contentType: 'audio/wav', model, raw: data };
}
