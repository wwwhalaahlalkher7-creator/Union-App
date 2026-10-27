/** Mistral provider adapter. API contracts are isolated here. */
import { openAiCompatibleChat, openAiCompatibleVision } from './generic_openai.js';

export const MISTRAL_DEFAULTS = Object.freeze({
  text: 'mistral-small-2603',
  vision: 'mistral-small-2603',
  ocr: 'mistral-ocr-latest',
  stt: 'voxtral-mini-2602',
  tts: 'voxtral-mini-tts-2603',
});

export function mistralChat(args) { return openAiCompatibleChat({ provider: 'mistral', ...args }); }
export function mistralVision(args) { return openAiCompatibleVision({ provider: 'mistral', ...args }); }

function providerError(status, body) {
  const error = new Error(`mistral request failed with status ${status}`);
  error.provider = 'mistral'; error.status = status; error.body = body; return error;
}

export async function mistralOcr({ baseUrl, apiKey, model = MISTRAL_DEFAULTS.ocr, file, contentType, signal }) {
  if (!apiKey) throw new Error('MISTRAL_API_KEY is empty');
  const bytes = Uint8Array.from(file instanceof ArrayBuffer ? new Uint8Array(file) : file);
  let binary = ''; for (const byte of bytes) binary += String.fromCharCode(byte);
  const dataUrl = `data:${contentType || 'application/octet-stream'};base64,${btoa(binary)}`;
  const response = await fetch(`${String(baseUrl || 'https://api.mistral.ai').replace(/\/+$/, '')}/v1/ocr`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({ model, document: { type: contentType === 'application/pdf' ? 'document_url' : 'image_url', ...(contentType === 'application/pdf' ? { document_url: dataUrl } : { image_url: dataUrl }) } }),
    signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  const data = await response.json();
  const text = Array.isArray(data?.pages) ? data.pages.map((p) => p?.markdown || p?.text || '').filter(Boolean).join('\n\n') : String(data?.document_annotation || data?.text || '').trim();
  if (!text) throw providerError(response.status, 'empty OCR result');
  return { text: text.trim(), model: data?.model || model, usage: data?.usage_info || null, raw: data };
}

async function multipartAudio({ baseUrl, apiKey, model, file, filename, contentType, fields = {}, signal, path }) {
  if (!apiKey) throw new Error('MISTRAL_API_KEY is empty');
  const form = new FormData();
  form.append('model', model);
  for (const [k, v] of Object.entries(fields)) form.append(k, String(v));
  form.append('file', new File([file], filename || 'audio', { type: contentType || 'application/octet-stream' }));
  const response = await fetch(`${String(baseUrl || 'https://api.mistral.ai').replace(/\/+$/, '')}${path}`, { method: 'POST', headers: { authorization: `Bearer ${apiKey}` }, body: form, signal });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  return response.json();
}

export async function mistralStt({ baseUrl, apiKey, model = MISTRAL_DEFAULTS.stt, file, filename, contentType, language, signal }) {
  const data = await multipartAudio({ baseUrl, apiKey, model, file, filename, contentType, fields: language && language !== 'auto' ? { language } : {}, signal, path: '/v1/audio/transcriptions' });
  const text = String(data?.text || data?.transcript || '').trim(); if (!text) throw providerError(200, 'empty transcription');
  return { text, model: data?.model || model, raw: data };
}

export async function mistralTts({ baseUrl, apiKey, model = MISTRAL_DEFAULTS.tts, text, voice, signal }) {
  if (!apiKey) throw new Error('MISTRAL_API_KEY is empty');
  const response = await fetch(`${String(baseUrl || 'https://api.mistral.ai').replace(/\/+$/, '')}/v1/audio/speech`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` }, body: JSON.stringify({ model, input: text, voice, response_format: 'mp3' }), signal,
  });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  const blob = await response.arrayBuffer();
  let binary = ''; for (const byte of new Uint8Array(blob)) binary += String.fromCharCode(byte);
  return { audioBase64: btoa(binary), contentType: 'audio/mpeg', model, raw: null };
}
