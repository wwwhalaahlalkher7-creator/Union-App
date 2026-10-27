const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

function base64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function encodeText(value) {
  return new TextEncoder().encode(value);
}

function pemBytes(pem) {
  const clean = String(pem || '').replace(/-----BEGIN PRIVATE KEY-----/g, '').replace(/-----END PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function getAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(encodeText(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64Url(encodeText(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  })));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8', pemBytes(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encodeText(unsigned));
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.access_token) throw new Error(`FCM_OAUTH_${response.status}`);
  return data.access_token;
}

function retryMinutes(attempt) {
  return Math.min(60, 2 ** Math.min(Math.max(attempt, 1), 6));
}

async function sendMessage(projectId, accessToken, row) {
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      message: {
        token: row.token,
        notification: { title: String(row.title || 'TRINEX'), body: String(row.body || '') },
        data: {
          notificationId: String(row.notification_target_id),
          announcementId: String(row.announcement_id),
          type: String(row.type || 'announcement'),
        },
        android: { priority: 'high' },
      },
    }),
  });
  const result = await response.json().catch(() => ({}));
  return { ok: response.ok, status: response.status, result };
}

function isInvalidDeviceToken(result) {
  const details = result?.error?.details;
  return Array.isArray(details) && details.some((detail) => detail?.errorCode === 'UNREGISTERED');
}

/**
 * Drain a bounded number of pending FCM deliveries. Credentials are provided as a
 * Cloudflare Worker secret named FCM_SERVICE_ACCOUNT_JSON; never put them in source.
 */
export async function dispatchPushNotifications(env, limit = 40) {
  const rawAccount = env.FCM_SERVICE_ACCOUNT_JSON;
  if (!rawAccount) return { skipped: 'FCM_SERVICE_ACCOUNT_JSON is not configured', processed: 0 };

  let account;
  try { account = JSON.parse(rawAccount); } catch (_) {
    return { skipped: 'FCM service-account secret is not valid JSON', processed: 0 };
  }
  if (!account.project_id || !account.client_email || !account.private_key) {
    return { skipped: 'FCM service-account secret is missing required fields', processed: 0 };
  }

  const rowsResult = await env.DB.prepare(`
    SELECT q.id AS queue_id, q.notification_target_id, q.device_id, q.attempts,
           nd.token, a.id AS announcement_id, a.title, a.body, a.type
      FROM notification_dispatch_queue q
      JOIN notification_targets nt ON nt.id=q.notification_target_id
      JOIN announcements a ON a.id=nt.announcement_id
      JOIN notification_devices nd ON nd.id=q.device_id AND nd.active=1
     WHERE q.channel='push' AND q.status='pending' AND q.scheduled_at<=CURRENT_TIMESTAMP
       AND a.status='published'
       AND (a.publish_at IS NULL OR a.publish_at<=CURRENT_TIMESTAMP)
       AND (a.expires_at IS NULL OR a.expires_at>CURRENT_TIMESTAMP)
     ORDER BY q.scheduled_at ASC, q.created_at ASC
     LIMIT ?
  `).bind(Math.max(1, Math.min(100, Number(limit) || 40))).all();
  const rows = rowsResult.results || [];
  if (!rows.length) return { processed: 0, delivered: 0, retried: 0, disabled: 0 };

  let accessToken;
  try { accessToken = await getAccessToken(account); }
  catch (_) { return { skipped: 'FCM authentication failed; queue left untouched', processed: 0 }; }

  let delivered = 0;
  let retried = 0;
  let disabled = 0;
  for (const row of rows) {
    const attempt = Number(row.attempts || 0) + 1;
    try {
      const result = await sendMessage(account.project_id, accessToken, row);
      if (result.ok) {
        await env.DB.batch([
          env.DB.prepare("UPDATE notification_dispatch_queue SET status='delivered', attempts=?, delivered_at=CURRENT_TIMESTAMP, last_error=NULL WHERE id=? AND status='pending'").bind(attempt, row.queue_id),
          env.DB.prepare('UPDATE notification_targets SET delivered_at=COALESCE(delivered_at,CURRENT_TIMESTAMP) WHERE id=?').bind(row.notification_target_id),
        ]);
        delivered += 1;
      } else if (isInvalidDeviceToken(result.result)) {
        await env.DB.batch([
          env.DB.prepare("UPDATE notification_dispatch_queue SET status='failed', attempts=?, last_error='FCM_DEVICE_TOKEN_INVALID' WHERE id=?").bind(attempt, row.queue_id),
          env.DB.prepare('UPDATE notification_devices SET active=0, updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(row.device_id),
        ]);
        disabled += 1;
      } else if (attempt >= 8) {
        await env.DB.prepare("UPDATE notification_dispatch_queue SET status='failed', attempts=?, last_error=? WHERE id=?")
          .bind(attempt, `FCM_HTTP_${result.status}_MAX_ATTEMPTS`, row.queue_id).run();
      } else {
        const delay = retryMinutes(attempt);
        const code = `FCM_HTTP_${result.status}`;
        await env.DB.prepare("UPDATE notification_dispatch_queue SET attempts=?, last_error=?, scheduled_at=datetime('now', ?) WHERE id=? AND status='pending'")
          .bind(attempt, code, `+${delay} minutes`, row.queue_id).run();
        retried += 1;
      }
    } catch (_) {
      if (attempt >= 8) {
        await env.DB.prepare("UPDATE notification_dispatch_queue SET status='failed', attempts=?, last_error='FCM_NETWORK_ERROR_MAX_ATTEMPTS' WHERE id=?")
          .bind(attempt, row.queue_id).run();
      } else {
        const delay = retryMinutes(attempt);
        await env.DB.prepare("UPDATE notification_dispatch_queue SET attempts=?, last_error='FCM_NETWORK_ERROR', scheduled_at=datetime('now', ?) WHERE id=? AND status='pending'")
          .bind(attempt, `+${delay} minutes`, row.queue_id).run();
        retried += 1;
      }
    }
  }
  return { processed: rows.length, delivered, retried, disabled };
}
