const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
let cachedAccessToken = null;
let cachedAccessTokenExpiry = 0;

function b64url(input) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = ''; for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
function pemBytes(pem) {
  const raw = String(pem).replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const bin = atob(raw); return Uint8Array.from(bin, c => c.charCodeAt(0));
}
async function getFcmAccessToken(env) {
  if (cachedAccessToken && Date.now() < cachedAccessTokenExpiry - 60000) return cachedAccessToken;
  if (!env.FCM_SERVICE_ACCOUNT_JSON) throw new Error('FCM_SERVICE_ACCOUNT_JSON secret is not configured');
  const account = JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON);
  if (!account.client_email || !account.private_key || !account.project_id) throw new Error('FCM service account JSON is incomplete');
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(JSON.stringify({ iss: account.client_email, scope: FCM_SCOPE, aud: account.token_uri || 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 }));
  const unsigned = `${head}.${claim}`;
  const key = await crypto.subtle.importKey('pkcs8', pemBytes(account.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const assertion = `${unsigned}.${b64url(new Uint8Array(signature))}`;
  const response = await fetch(account.token_uri || 'https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const data = await response.json();
  if (!response.ok || !data.access_token) throw new Error(`FCM OAuth failed (${response.status})`);
  cachedAccessToken = data.access_token; cachedAccessTokenExpiry = Date.now() + Number(data.expires_in || 3600) * 1000;
  return cachedAccessToken;
}

async function sendFcm(env, token, title, body, announcementId) {
  const account = JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON);
  const accessToken = await getFcmAccessToken(env);
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
    method: 'POST', headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ message: { token, notification: { title: String(title || 'إشعار جديد').slice(0, 180), body: String(body || '').slice(0, 900) }, data: { announcementId: String(announcementId), type: 'announcement' }, android: { priority: 'HIGH', notification: { channel_id: 'association_notifications' } } } }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = JSON.stringify(data).slice(0, 500);
    const err = new Error(`FCM send failed (${response.status}): ${detail}`); err.status = response.status; err.detail = data; throw err;
  }
  return data;
}

async function materializeDueAnnouncements(env) {
  const now = new Date().toISOString();
  const due = await env.DB.prepare(`SELECT id, target_department_id, target_semester_id FROM announcements a
    WHERE a.status='published' AND (a.publish_at IS NULL OR a.publish_at <= ?)
      AND (a.expires_at IS NULL OR a.expires_at > ?)
      AND NOT EXISTS (SELECT 1 FROM notification_targets nt WHERE nt.announcement_id=a.id)
      AND NOT EXISTS (SELECT 1 FROM notification_schedule_runs sr WHERE sr.announcement_id=a.id)
    ORDER BY COALESCE(a.publish_at,a.created_at) ASC LIMIT 20`).bind(now, now).all();
  for (const a of (due.results || [])) {
    const dept = a.target_department_id || null, sem = a.target_semester_id || null;
    await env.DB.prepare(`INSERT OR IGNORE INTO notification_targets (id, announcement_id, student_id)
      SELECT lower(hex(randomblob(16))), ?, s.id FROM students s
      WHERE s.active=1 AND s.auth_secret_hash IS NOT NULL
        AND (? IS NULL OR s.department_id=?)
        AND (? IS NULL OR s.current_semester_id=?)
    `).bind(a.id, dept, dept, sem, sem).run();
    await env.DB.batch([
      env.DB.prepare(`INSERT OR IGNORE INTO notification_dispatch_queue (id, notification_target_id, device_id, channel)
        SELECT lower(hex(randomblob(16))), nt.id, nd.id, 'push' FROM notification_targets nt
        JOIN notification_devices nd ON nd.student_id=nt.student_id AND nd.active=1
        WHERE nt.announcement_id=? AND NOT EXISTS (SELECT 1 FROM notification_dispatch_queue q WHERE q.notification_target_id=nt.id AND q.device_id=nd.id AND q.channel='push')`).bind(a.id),
      env.DB.prepare(`INSERT OR IGNORE INTO notification_dispatch_queue (id, notification_target_id, channel)
        SELECT lower(hex(randomblob(16))), nt.id, 'in_app' FROM notification_targets nt
        WHERE nt.announcement_id=? AND NOT EXISTS (SELECT 1 FROM notification_dispatch_queue q WHERE q.notification_target_id=nt.id AND q.device_id IS NULL AND q.channel='in_app')`).bind(a.id),
    ]);
    const targetCount = await env.DB.prepare('SELECT COUNT(*) AS n FROM notification_targets WHERE announcement_id=?').bind(a.id).first();
    await env.DB.prepare('INSERT OR IGNORE INTO notification_schedule_runs (announcement_id, processed_at, target_count) VALUES (?, ?, ?)')
      .bind(a.id, now, Number(targetCount?.n || 0)).run();
  }
}

export async function processNotificationQueue(env) {
  const now = new Date().toISOString();
  await materializeDueAnnouncements(env);
  const result = await env.DB.prepare(`SELECT q.id, q.channel, q.attempts, q.notification_target_id, q.device_id,
      nt.student_id, nt.announcement_id, a.title, a.body, nd.token
    FROM notification_dispatch_queue q
    JOIN notification_targets nt ON nt.id=q.notification_target_id
    JOIN announcements a ON a.id=nt.announcement_id
    LEFT JOIN notification_devices nd ON nd.id=q.device_id
    WHERE q.status='pending' AND q.scheduled_at <= ? AND q.attempts < 5
      AND (q.channel='in_app' OR ?=1)
      AND a.status='published' AND (a.publish_at IS NULL OR a.publish_at <= ?)
      AND (a.expires_at IS NULL OR a.expires_at > ?)
    ORDER BY q.created_at ASC LIMIT 50`).bind(now, env.FCM_SERVICE_ACCOUNT_JSON ? 1 : 0, now, now).all();
  for (const row of (result.results || [])) {
    // Claim one row before network I/O to prevent concurrent scheduled invocations duplicating sends.
    const claim = await env.DB.prepare(`UPDATE notification_dispatch_queue SET status='processing', attempts=attempts+1 WHERE id=? AND status='pending'`).bind(row.id).run();
    if (!Number(claim.meta?.changes || 0)) continue;
    try {
      if (row.channel === 'push' && row.token) {
        await sendFcm(env, row.token, row.title, row.body, row.announcement_id);
      }
      await env.DB.prepare(`UPDATE notification_dispatch_queue SET status='sent', delivered_at=?, last_error=NULL WHERE id=?`).bind(now, row.id).run();
      await env.DB.prepare(`UPDATE notification_targets SET delivered_at=COALESCE(delivered_at, ?) WHERE id=?`).bind(now, row.notification_target_id).run();
    } catch (e) {
      const message = String(e?.message || e).slice(0, 500);
      const attempts = Number(row.attempts || 0) + 1;
      const terminal = attempts >= 5;
      await env.DB.prepare(`UPDATE notification_dispatch_queue SET status=?, scheduled_at=?, last_error=? WHERE id=?`)
        .bind(terminal ? 'failed' : 'pending', new Date(Date.now() + Math.min(attempts * 60000, 900000)).toISOString(), message, row.id).run();
      if (e?.status === 404 || /UNREGISTERED|INVALID_ARGUMENT/.test(JSON.stringify(e?.detail || {}))) {
        if (row.device_id) await env.DB.prepare('UPDATE notification_devices SET active=0, updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(row.device_id).run();
      }
    }
  }
}
