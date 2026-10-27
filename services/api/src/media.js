import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
} from './core.js';
import { requireAdminPermission } from './admin.js';
import { writeAudit } from './admin.js';
export function mediaUrlFor(ctx, key) {
  return `${new URL(ctx.request.url).origin}/api/v1/media/${key.split('/').map(encodeURIComponent).join('/')}`;
}

export function mediaKeyFromUrl(ctx, value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  try {
    const url = new URL(raw, new URL(ctx.request.url).origin);
    if (url.origin !== new URL(ctx.request.url).origin) return null;
    const prefix = '/api/v1/media/';
    if (!url.pathname.startsWith(prefix)) return null;
    const encoded = url.pathname.slice(prefix.length);
    if (!encoded || encoded.includes('..')) return null;
    return encoded.split('/').map(decodeURIComponent).join('/');
  } catch (_) { return null; }
}

export function imageMagicValid(type, bytes) {
  if (type === 'image/jpeg') return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (type === 'image/png') return bytes.length >= 8 && bytes.slice(0, 8).every((v, i) => v === [137,80,78,71,13,10,26,10][i]);
  if (type === 'image/webp') return bytes.length >= 12 && new TextDecoder().decode(bytes.slice(0,4)) === 'RIFF' && new TextDecoder().decode(bytes.slice(8,12)) === 'WEBP';
  return false;
}

export async function reserveR2Upload(ctx, sizeBytes) {
  const month = currentQuotaMonth();
  const result = await ctx.env.DB.prepare(`
    UPDATE media_quota
       SET storage_bytes = storage_bytes + ?,
           class_a_used = CASE WHEN quota_month = ? THEN class_a_used + 1 ELSE 1 END,
           quota_month = ?,
           updated_at = CURRENT_TIMESTAMP
     WHERE id = 1
       AND storage_bytes + ? <= ?
       AND (CASE WHEN quota_month = ? THEN class_a_used ELSE 0 END) < ?
  `).bind(sizeBytes, month, month, sizeBytes, R2_MAX_STORAGE_BYTES, month, R2_MAX_CLASS_A_MONTHLY).run();
  return Boolean(result.meta?.changes);
}

export async function releaseR2Reservation(ctx, sizeBytes) {
  await ctx.env.DB.prepare(`
    UPDATE media_quota
       SET storage_bytes = MAX(0, storage_bytes - ?), updated_at = CURRENT_TIMESTAMP
     WHERE id = 1
  `).bind(sizeBytes).run();
}

export async function cleanupUnattachedMedia(ctx) {
  if (!ctx.env.MEDIA_BUCKET) return;
  const rows = await queryAll(ctx.env, `SELECT object_key,size_bytes FROM media_assets WHERE attached_at IS NULL AND created_at < datetime('now','-1 hour') LIMIT 50`);
  if (!rows.length) return;
  const deleted = [];
  for (const row of rows) {
    try { await ctx.env.MEDIA_BUCKET.delete(row.object_key); deleted.push(row); } catch (_) {}
  }
  if (!deleted.length) return;
  try {
    await ctx.env.DB.prepare(`DELETE FROM media_assets WHERE object_key IN (${deleted.map(() => '?').join(',')})`).bind(...deleted.map(r => r.object_key)).run();
    await releaseR2Reservation(ctx, deleted.reduce((sum, r) => sum + Number(r.size_bytes || 0), 0));
  } catch (_) {}
}

export async function adminMediaUpload(ctx) {
  const a = await requireAdminPermission(ctx, 'content.write');
  if (a.response) return a.response;
  if (!ctx.env.MEDIA_BUCKET) return error('R2_NOT_CONFIGURED', 'تخزين الوسائط غير مهيأ على الخادم.', 503, ctx.requestId, ctx.cors);

  let form;
  try { form = await ctx.request.formData(); } catch (_) { return error('MEDIA_MULTIPART_REQUIRED', 'أرسل الملف بصيغة multipart/form-data.', 400, ctx.requestId, ctx.cors); }
  await cleanupUnattachedMedia(ctx);
  const files = form.getAll('file').filter(v => v instanceof File);
  if (!files.length || files.length > R2_MAX_UPLOAD_FILES_PER_REQUEST) return error('MEDIA_FILE_COUNT_INVALID', `يمكن رفع من 1 إلى ${R2_MAX_UPLOAD_FILES_PER_REQUEST} صور في الطلب الواحد.`, 400, ctx.requestId, ctx.cors);

  const prepared = [];
  for (const file of files) {
    const type = String(file.type || '').toLowerCase();
    const ext = R2_ALLOWED_TYPES[type];
    if (!ext) return error('MEDIA_TYPE_NOT_ALLOWED', 'مسموح فقط بصور JPEG أو PNG أو WebP.', 415, ctx.requestId, ctx.cors);
    if (!Number.isFinite(file.size) || file.size <= 0 || file.size > R2_MAX_OBJECT_BYTES) return error('MEDIA_SIZE_EXCEEDED', 'حجم كل صورة يجب ألا يتجاوز 3MB.', 413, ctx.requestId, ctx.cors);
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (!imageMagicValid(type, bytes)) return error('MEDIA_CONTENT_INVALID', 'محتوى أحد الملفات لا يطابق نوع الصورة المعلن.', 400, ctx.requestId, ctx.cors);
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    const sha = [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
    prepared.push({ file, type, ext, bytes, sha });
  }

  const totalBytes = prepared.reduce((sum, item) => sum + item.bytes.byteLength, 0);
  const month = currentQuotaMonth();
  // Reserve the whole request up front so a multi-image publish cannot partially
  // consume the safety budget. One R2 PutObject is expected per image (all files
  // are deliberately capped at 3MB to avoid multipart uploads).
  const reserved = await ctx.env.DB.prepare(`
    UPDATE media_quota
       SET storage_bytes = storage_bytes + ?,
           class_a_used = CASE WHEN quota_month = ? THEN class_a_used + ? ELSE ? END,
           quota_month = ?,
           updated_at = CURRENT_TIMESTAMP
     WHERE id = 1
       AND storage_bytes + ? <= ?
       AND (CASE WHEN quota_month = ? THEN class_a_used ELSE 0 END) + ? <= ?
  `).bind(totalBytes, month, prepared.length, prepared.length, month, totalBytes, R2_MAX_STORAGE_BYTES, month, prepared.length, R2_MAX_CLASS_A_MONTHLY).run();
  if (!reserved.meta?.changes) return error('MEDIA_FREE_QUOTA_REACHED', 'تم بلوغ حد تخزين/رفع الوسائط الآمن. لا توجد عملية مدفوعة مسموحة.', 429, ctx.requestId, ctx.cors);

  const stored = [];
  const insertedKeys = [];
  try {
    for (const item of prepared) {
      const key = `media/${month}/${crypto.randomUUID()}.${item.ext}`;
      await ctx.env.MEDIA_BUCKET.put(key, item.bytes, {
        httpMetadata: { contentType: item.type, cacheControl: 'public, max-age=86400, s-maxage=86400, immutable' },
        customMetadata: { sha256: item.sha, originalName: String(item.file.name || '').slice(0, 200) },
      });
      stored.push({ key, sizeBytes: item.bytes.byteLength });
      await ctx.env.DB.prepare(`INSERT INTO media_assets (id, object_key, content_type, size_bytes, sha256, original_name, created_by) VALUES (?,?,?,?,?,?,?)`)
        .bind(crypto.randomUUID(), key, item.type, item.bytes.byteLength, item.sha, String(item.file.name || '').slice(0, 200), a.session.staff_user_id).run();
      insertedKeys.push(key);
    }
  } catch (e) {
    const deleted = [];
    for (const entry of stored) {
      try { await ctx.env.MEDIA_BUCKET.delete(entry.key); deleted.push(entry); } catch (_) {}
    }
    const deletedKeys = new Set(deleted.map(x => x.key));
    const insertedDeletedKeys = insertedKeys.filter(key => deletedKeys.has(key));
    if (insertedDeletedKeys.length) {
      try { await ctx.env.DB.prepare(`DELETE FROM media_assets WHERE object_key IN (${insertedDeletedKeys.map(() => '?').join(',')})`).bind(...insertedDeletedKeys).run(); } catch (_) {}
    }
    if (deleted.length) await releaseR2Reservation(ctx, deleted.reduce((sum, x) => sum + x.sizeBytes, 0));
    throw e;
  }

  const items = prepared.map((item, i) => ({
    key: stored[i].key,
    url: mediaUrlFor(ctx, stored[i].key),
    sizeBytes: item.bytes.byteLength,
    contentType: item.type,
    sha256: item.sha,
  }));
  await writeAudit(ctx, a.session.staff_user_id, 'upload', 'media', stored.map(x => x.key).join(','), { count: items.length, total_size_bytes: totalBytes, items: items.map(x => ({ key: x.key, size_bytes: x.sizeBytes, content_type: x.contentType })) });
  return ok(ctx, { items, key: items[0].key, url: items[0].url, sizeBytes: items[0].sizeBytes, contentType: items[0].contentType, sha256: items[0].sha256 }, null, 201);
}

export async function mediaGet(ctx) {
  if (!ctx.env.MEDIA_BUCKET) return error('R2_NOT_CONFIGURED', 'تخزين الوسائط غير مهيأ على الخادم.', 503, ctx.requestId, ctx.cors);
  const prefix = '/media/';
  const rawKey = ctx.path.slice(prefix.length);
  let key;
  try { key = rawKey.split('/').map(decodeURIComponent).join('/'); } catch (_) { return error('MEDIA_KEY_INVALID', 'معرّف الوسيط غير صالح.', 400, ctx.requestId, ctx.cors); }
  if (!key || key.includes('..') || !key.startsWith('media/')) return error('MEDIA_KEY_INVALID', 'معرّف الوسيط غير صالح.', 400, ctx.requestId, ctx.cors);
  const object = await ctx.env.MEDIA_BUCKET.get(key);
  if (!object) return error('MEDIA_NOT_FOUND', 'الوسيط غير موجود.', 404, ctx.requestId, ctx.cors);
  const h = new Headers();
  object.writeHttpMetadata(h);
  h.set('etag', object.httpEtag);
  h.set('cache-control', h.get('cache-control') || 'public, max-age=86400, s-maxage=86400, immutable');
  h.set('x-content-type-options', 'nosniff');
  h.set('content-security-policy', "default-src 'none'; frame-ancestors 'none'; object-src 'none'");
  return new Response(object.body, { status: 200, headers: h });
}

export async function deleteOwnedMediaUrls(ctx, urls) {
  if (!ctx.env.MEDIA_BUCKET) return;
  const keys = [...new Set((urls || []).map(v => mediaKeyFromUrl(ctx, v)).filter(Boolean))];
  if (!keys.length) return;
  const rows = await queryAll(ctx.env, `SELECT object_key,size_bytes FROM media_assets WHERE object_key IN (${keys.map(() => '?').join(',')})`, ...keys);
  const deletedKeys = [];
  for (const key of keys) {
    try { await ctx.env.MEDIA_BUCKET.delete(key); deletedKeys.push(key); } catch (_) {}
  }
  const deletedRows = rows.filter(r => deletedKeys.includes(r.object_key));
  if (deletedRows.length) {
    try {
      await ctx.env.DB.prepare(`DELETE FROM media_assets WHERE object_key IN (${deletedRows.map(() => '?').join(',')})`).bind(...deletedRows.map(r => r.object_key)).run();
      await releaseR2Reservation(ctx, deletedRows.reduce((sum, r) => sum + Number(r.size_bytes || 0), 0));
    } catch (_) {}
  }
}

export function extractMediaUrlsFromRow(ctx, row) {
  const urls = [];
  if (row?.image_url) urls.push(row.image_url);
  const images = parseJsonValue(row?.images_json, []);
  if (Array.isArray(images)) for (const item of images) {
    const url = typeof item === 'string' ? item : item?.url;
    if (url) urls.push(url);
  }
  return [...new Set(urls)];
}

export async function markOwnedMediaAttached(ctx, urls) {
  const keys = [...new Set((urls || []).map(v => mediaKeyFromUrl(ctx, v)).filter(Boolean))];
  if (!keys.length) return;
  await ctx.env.DB.prepare(`UPDATE media_assets SET attached_at=CURRENT_TIMESTAMP WHERE object_key IN (${keys.map(() => '?').join(',')})`).bind(...keys).run();
}
