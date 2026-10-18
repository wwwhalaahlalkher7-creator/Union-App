const DEFAULT_MODEL = 'nova-3';

function providerError(status, body) {
  const e = new Error(`deepgram request failed with status ${status}`);
  e.provider = 'deepgram'; e.status = status; e.body = body; return e;
}

export async function deepgramStt({ apiKey, model = DEFAULT_MODEL, file, language = 'ar', contentType = 'audio/wav', signal }) {
  if (!apiKey) throw new Error('DEEPGRAM_API_KEY is empty');
  const url = new URL('https://api.deepgram.com/v1/listen');
  url.searchParams.set('model', model);
  url.searchParams.set('language', language);
  url.searchParams.set('smart_format', 'true');
  const response = await fetch(url, { method: 'POST', headers: { authorization: `Token ${apiKey}`, 'content-type': contentType || 'application/octet-stream' }, body: file, signal });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  const data = await response.json();
  const text = String(data?.results?.channels?.[0]?.alternatives?.[0]?.transcript || '').trim();
  if (!text) throw providerError(response.status, 'empty transcription');
  return { text, model: data?.metadata?.model_info ? Object.keys(data.metadata.model_info)[0] : model, raw: data };
}
