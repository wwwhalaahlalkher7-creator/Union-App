/** Groq provider adapter. */
import { openAiCompatibleChat, openAiCompatibleVision } from './generic_openai.js';

export const GROQ_DEFAULTS = Object.freeze({
  text: 'openai/gpt-oss-120b',
  vision: 'qwen/qwen3.8-27b',
  stt: 'whisper-large-v3-turbo',
  tts: 'canopylabs/orpheus-arabic-saudi',
});

export function groqChat(args) { return openAiCompatibleChat({ provider: 'groq', ...args }); }
export function groqVision(args) { return openAiCompatibleVision({ provider: 'groq', ...args }); }

function providerError(status, body) { const e = new Error(`groq request failed with status ${status}`); e.provider = 'groq'; e.status = status; e.body = body; return e; }

export async function groqStt({ baseUrl = 'https://api.groq.com/openai/v1', apiKey, model = GROQ_DEFAULTS.stt, file, filename, contentType, language, signal }) {
  if (!apiKey) throw new Error('GROQ_API_KEY is empty');
  const form = new FormData(); form.append('file', new File([file], filename || 'audio', { type: contentType || 'application/octet-stream' })); form.append('model', model); if (language && language !== 'auto') form.append('language', language);
  const response = await fetch(`${String(baseUrl).replace(/\/+$/, '')}/audio/transcriptions`, { method: 'POST', headers: { authorization: `Bearer ${apiKey}` }, body: form, signal });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  const data = await response.json(); const text = String(data?.text || '').trim(); if (!text) throw providerError(response.status, 'empty transcription');
  return { text, model: data?.model || model, raw: data };
}

export async function groqTts({ baseUrl = 'https://api.groq.com/openai/v1', apiKey, model = GROQ_DEFAULTS.tts, text, voice, signal }) {
  if (!apiKey) throw new Error('GROQ_API_KEY is empty');
  const response = await fetch(`${String(baseUrl).replace(/\/+$/, '')}/audio/speech`, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` }, body: JSON.stringify({ model, input: text, voice: voice || model }), signal });
  if (!response.ok) throw providerError(response.status, await response.text().catch(() => ''));
  const blob = await response.arrayBuffer(); let binary = ''; for (const byte of new Uint8Array(blob)) binary += String.fromCharCode(byte);
  return { audioBase64: btoa(binary), contentType: response.headers.get('content-type') || 'audio/wav', model, raw: null };
}
