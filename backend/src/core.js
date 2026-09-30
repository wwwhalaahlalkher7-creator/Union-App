export const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

export const PUBLIC_MAX = 50;
export const AUTH_ACCESS_TTL = 15 * 60;
export const AUTH_REFRESH_TTL = 30 * 24 * 60 * 60;
export const AUTH_MAX_FAILED = 5;
export const AUTH_LOCK_SECONDS = 15 * 60;
export const AUTH_IP_WINDOW_SECONDS = 5 * 60;
export const AUTH_IP_LOGIN_LIMIT = 10;
export const AUTH_IP_REFRESH_LIMIT = 30;
// Cloudflare Workers CPU-safe work factor for WebCrypto PBKDF2.
// Keep this value aligned between bootstrap and staff login.
export const PBKDF2_ITERATIONS = 15000;
export const XP_DAILY_CAP = 500;
export const XP_LEVEL_BASE = 100;
export const EINO_MAX_MESSAGE = 4000;
export const EINO_MAX_CONTEXT = 6000;
export const EINO_WINDOW_SECONDS = 10 * 60;
export const EINO_WINDOW_LIMIT = 20;
export const EINO_STUDENT_DAILY_LIMIT_DEFAULT = 100;
export const EINO_GUEST_DAILY_LIMIT_DEFAULT = 20;
export const EINO_GLOBAL_DAILY_LIMIT_DEFAULT = 2000;

// R2 safety budget: deliberately below Cloudflare's free-tier ceiling.
// The Worker itself is also on the Free plan, so routing media reads through
// this Worker bounds application-driven R2 Class B reads by the Worker request
// ceiling. R2 Standard storage is capped much lower here as an extra margin.
export const R2_MAX_OBJECT_BYTES = 3 * 1024 * 1024;
export const R2_MAX_STORAGE_BYTES = 6 * 1024 * 1024 * 1024; // 6 GiB
export const R2_MAX_CLASS_A_MONTHLY = 100000;
export const R2_MAX_UPLOAD_FILES_PER_REQUEST = 5;
export const R2_ALLOWED_TYPES = Object.freeze({
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
});

export function headers(ctx, extra = {}) {
  return {
    ...JSON_HEADERS,
    ...ctx.cors,
    'x-request-id': ctx.requestId,
    'x-content-type-options': 'nosniff',
    'x-frame-options': 'DENY',
    'referrer-policy': 'no-referrer',
    'permissions-policy': 'camera=(), microphone=(), geolocation=(), payment=()',
    'cross-origin-opener-policy': 'same-origin',
    'x-permitted-cross-domain-policies': 'none',
    'cache-control': 'no-store',
    'content-security-policy': "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'; object-src 'none'",
    ...extra,
  };
}

export function json(ctx, payload, status = 200, extra = {}) {
  return new Response(JSON.stringify(payload), { status, headers: headers(ctx, extra) });
}

export function ok(ctx, data, meta = null, status = 200) {
  return json(ctx, { success: true, data, ...(meta ? { meta } : {}) }, status);
}

export function databaseErrorResponse(e, requestId, cors) {
  const message = String(e?.message || e || '');
  if (/UNIQUE constraint failed/i.test(message)) {
    return error('CONFLICT', 'البيانات موجودة بالفعل أو تتعارض مع سجل موجود.', 409, requestId, cors);
  }
  if (/FOREIGN KEY constraint failed|NOT NULL constraint failed|CHECK constraint failed/i.test(message)) {
    return error('DATA_CONSTRAINT', 'البيانات المرسلة لا تتوافق مع العلاقات أو القيود الحالية.', 400, requestId, cors);
  }
  return error('INTERNAL_ERROR', 'حدث خطأ غير متوقع. حاول مرة أخرى.', 500, requestId, cors);
}

export function error(code, message, status = 400, requestId = crypto.randomUUID(), cors = {}, details = null) {
  const safeDetails = details == null ? null : String(details).slice(0, 500);
  return new Response(JSON.stringify({ success: false, error: { code, message, details: safeDetails, requestId } }), {
    status,
    headers: {
      ...JSON_HEADERS,
      ...cors,
      'x-request-id': requestId,
      'x-content-type-options': 'nosniff',
      'x-frame-options': 'DENY',
      'referrer-policy': 'no-referrer',
      'permissions-policy': 'camera=(), microphone=(), geolocation=(), payment=()',
      'cross-origin-opener-policy': 'same-origin',
      'x-permitted-cross-domain-policies': 'none',
      'cache-control': 'no-store',
      'content-security-policy': "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'; object-src 'none'",
    },
  });
}

export async function parseJson(request) {
  try { return await request.json(); } catch { return null; }
}

export function clampInt(value, fallback, min = 1, max = PUBLIC_MAX) {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
}

export async function queryAll(env, sql, ...bindings) {
  const result = await env.DB.prepare(sql).bind(...bindings).all();
  return result.results || [];
}

export async function queryOne(env, sql, ...bindings) {
  return await env.DB.prepare(sql).bind(...bindings).first();
}

export function rowMap(rows) { return rows; }

export function parseJsonValue(value, fallback = null) {
  if (value === null || value === undefined || value === '') return fallback;
  try { return JSON.parse(value); } catch { return fallback; }
}

export function currentQuotaMonth() {
  const d = new Date();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

export function bearer(request) {
  const value = request.headers.get('Authorization') || '';
  return value.startsWith('Bearer ') ? value.slice(7).trim() : '';
}

export async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(hash)].map(b => b.toString(16).padStart(2, '0')).join('');
}

export function token(bytes = 32) {
  const data = new Uint8Array(bytes); crypto.getRandomValues(data);
  return btoa(String.fromCharCode(...data)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export async function pbkdf2Hash(secret, salt, iterations = PBKDF2_ITERATIONS) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt: new TextEncoder().encode(salt), iterations, hash: 'SHA-256' }, key, 256);
  return [...new Uint8Array(bits)].map(b => b.toString(16).padStart(2, '0')).join('');
}

export function timingSafeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function makeId(prefix) { return `${prefix}-${crypto.randomUUID()}`; }

export function sqlValue(v) { return v === undefined ? null : v; }

export function positiveInt(value, fallback) {
  const n = Number.parseInt(String(value ?? ''), 10);
  return Number.isSafeInteger(n) && n > 0 ? n : fallback;
}
