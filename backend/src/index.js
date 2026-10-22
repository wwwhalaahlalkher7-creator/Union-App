import { processNotificationQueue } from './notifications.js';
export { TrinexScheduler } from './scheduler.js';
import { adminUsageAnalytics, recordUsageEvent } from './analytics.js';
import { databaseErrorResponse, error } from './core.js';
import { publicVersion, appUpdate, health, publicContentDetail, publicList, publicMaterials, publicSettings, publicStudentProfile } from './public.js';
import { mediaGet, adminMediaUpload } from './media.js';
import { publicChatMessages, createPublicChatMessage, deleteOwnPublicChatMessage, reportPublicChatMessage } from './chat.js';
import { createStudentFeedback } from './feedback.js';
import {
  login, registerStudent, studentChangePassword, forgotStudentPassword, resetStudentPassword, staffLogin, staffBootstrap, staffMe, staffUpdateMe, staffChangePassword,
  refresh, logout, authMe,
} from './auth.js';
import {
  studentMe, updateStudentSemester, studentStats, studentNotifications, studentNotificationRead,
  registerNotificationDevice, unregisterNotificationDevice, deleteStudentNotification,
} from './student.js';
import {
  semesters, departments, subjects, materials, exams, materialFile, materialById, schedule,
  progress, xp, badges, materialProgress,
} from './academic.js';
import {
  comments, createComment, replies, createReply, reaction, removeReaction, commentReaction, removeCommentReaction, deleteComment, deleteOwnReply,
} from './interactions.js';
import {
  adminNotifications, adminNotificationSend,
  adminAuthEvents, adminModerationComments, adminModerationComment, adminModerationReplies, adminModerationReply, adminDeleteReply, adminDashboardOverview,
  adminEinoUsage, adminEinoMonitor, adminChatReports, adminChatReportUpdate, adminFeedbackReports, adminFeedbackReportUpdate, adminModerationInbox, adminSetStudentModerator, adminRoute,
} from './admin.js';
import { adminDriveSync, adminDriveSyncStatus, adminUploadMaterialPdf } from './drive.js';
import {
  eino, einoCapabilities, einoModels, einoMemoryList, einoMemoryCreate, einoMemoryDelete,
  einoConversationCreate, einoConversationList, einoConversationMessages, einoConversationMessageAppend, einoConversationDelete,
  einoVision, einoOcr, einoStt, einoTts, einoFileAnalysis, einoImage, einoLongSummary,
} from './eino.js';


function instrumentD1(database, metrics) {
  const originals = new WeakMap();
  const addMeta = (result) => {
    const meta = result?.meta || {};
    metrics.d1RowsRead += Math.max(0, Number(meta.rows_read || 0));
    metrics.d1RowsWritten += Math.max(0, Number(meta.rows_written || 0));
    return result;
  };
  const wrapStatement = (statement) => {
    const proxy = new Proxy(statement, {
    get(target, prop) {
      const value = target[prop];
      if (prop === 'bind' && typeof value === 'function') return (...args) => wrapStatement(value.apply(target, args));
      if (['run', 'all', 'first', 'raw'].includes(String(prop)) && typeof value === 'function') {
        return async (...args) => {
          metrics.d1Operations += 1;
          const result = await value.apply(target, args);
          return addMeta(result);
        };
      }
      return typeof value === 'function' ? value.bind(target) : value;
    },
    });
    originals.set(proxy, statement);
    return proxy;
  };
  return new Proxy(database, {
    get(target, prop) {
      const value = target[prop];
      if (prop === 'prepare' && typeof value === 'function') return (...args) => wrapStatement(value.apply(target, args));
      if (prop === 'batch' && typeof value === 'function') return async (statements) => {
        metrics.d1Operations += Array.isArray(statements) ? statements.length : 1;
        const unwrapped = Array.isArray(statements) ? statements.map((statement) => originals.get(statement) || statement) : statements;
        const result = await value.apply(target, [unwrapped]);
        if (Array.isArray(result)) result.forEach(addMeta);
        return result;
      };
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
}

function normalizedRoute(path) {
  const value = String(path || '/');
  // Never persist object keys or long resource identifiers in telemetry.
  if (value.startsWith('/media/')) return '/media/:key';
  return value.split('/').map((part) => {
    if (/^[0-9a-f]{8}-[0-9a-f-]{20,}$/i.test(part) || /^[0-9]{4,}$/.test(part) || part.length > 24) return ':id';
    return part;
  }).join('/').slice(0, 180) || '/';
}

async function persistResourceUsage(env, metrics, request, route, statusCode, durationMs) {
  // Keep telemetry inexpensive on the free tier: sample 10% of ordinary requests,
  // but record every request that touched R2 so R2 operations/bytes remain exact.
  const sampleWeight = metrics.r2Operations > 0 ? 1 : (Math.random() < 0.1 ? 10 : 0);
  if (!sampleWeight) return;
  // The telemetry insert is a real D1 write, so include it in sampled D1 totals.
  metrics.d1Operations += 1;
  metrics.d1RowsWritten += 1;
  try {
    await env.DB.prepare(`INSERT INTO resource_usage_events
      (id, route, method, status_code, duration_ms, d1_operations, d1_rows_read, d1_rows_written, r2_operations, r2_read_bytes, r2_written_bytes, sample_weight)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(crypto.randomUUID(), route, request.method, statusCode, durationMs,
        metrics.d1Operations, metrics.d1RowsRead, metrics.d1RowsWritten,
        metrics.r2Operations, metrics.r2ReadBytes, metrics.r2WrittenBytes, sampleWeight).run();
  } catch (e) {
    // Telemetry must never affect a user's request; schema migration may not be deployed yet.
    console.warn('Resource telemetry write skipped', String(e?.message || e).slice(0, 160));
  }
}

export default {
  async scheduled(event, env, ctx) {
    // The only remaining Cron is the low-frequency retention cleanup and a
    // daily recovery signal for alarms that predate deployment/config changes.
    if (event.cron === '0 * * * *') {
      ctx.waitUntil(env.DB.prepare("UPDATE import_operations SET status='expired',reviewed_json='[]',summary_json='{}' WHERE status='review' AND expires_at<=?")
        .bind(new Date().toISOString()).run().catch((e) => console.error('Expired scanner import cleanup failed', e)));
      return;
    }
    if (event.cron !== '0 3 * * *') return;
    ctx.waitUntil(Promise.all([
      env.DB.prepare("DELETE FROM usage_events WHERE created_at < datetime('now','-90 days')").run(),
      env.DB.prepare("DELETE FROM usage_sessions WHERE last_seen_at < datetime('now','-90 days')").run(),
      env.DB.prepare("DELETE FROM resource_usage_events WHERE created_at < datetime('now','-90 days')").run(),
    ]).catch((e) => console.error('Usage analytics retention cleanup failed', e)));
    if (env.SCHEDULER) {
      const scheduler = env.SCHEDULER.get(env.SCHEDULER.idFromName('main'));
      ctx.waitUntil(scheduler.fetch('https://scheduler/reschedule', { method: 'POST' })
        .catch((e) => console.error('Daily scheduler recovery failed', e)));
    }
  },
  async fetch(request, env, executionCtx) {
    const startedAt = Date.now();
    const metrics = { d1Operations: 0, d1RowsRead: 0, d1RowsWritten: 0, r2Operations: 0, r2ReadBytes: 0, r2WrittenBytes: 0 };
    const originalEnv = env;
    let metricRoute = '/';
    env = new Proxy(env, { get(target, prop) { return prop === 'DB' ? instrumentD1(target.DB, metrics) : target[prop]; } });
    const requestId = crypto.randomUUID();
    const requestOrigin = request.headers.get('Origin') || '';
    const allowedOrigins = String(env.ALLOWED_ORIGINS || '').split(',').map(v => v.trim()).filter(Boolean);
    const origin = requestOrigin && allowedOrigins.includes(requestOrigin) ? requestOrigin : '';
    const cors = {
      ...(origin ? { 'access-control-allow-origin': origin, 'vary': 'Origin' } : {}),
      'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
      'access-control-allow-headers': 'Content-Type, Authorization, X-Request-Id',
      'access-control-max-age': '86400',
    };

    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

    try {
      const url = new URL(request.url);
      const base = '/api/v1';
      if (!url.pathname.startsWith(base)) return error('NOT_FOUND', 'المسار غير موجود.', 404, requestId, cors);

      const path = url.pathname.slice(base.length) || '/';
      const ctx = { request, env, url, path, requestId, cors, metrics };
      const route = normalizedRoute(path);
      metricRoute = route;
      const response = await (async () => {
      // Reject unsupported verbs on administrative endpoints explicitly. OPTIONS is
      // handled above; admin handlers only support the methods declared by the API.
      if (path.startsWith('/admin/') && !['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method)) {
        return error('METHOD_NOT_ALLOWED', 'طريقة الطلب غير مدعومة لهذا المسار.', 405, requestId, cors);
      }

      if (request.method === 'GET' && path === '/health') return health(ctx);
      if (request.method === 'GET' && path === '/version') return publicVersion(ctx);
      if (path === '/usage/events' && request.method === 'POST') return recordUsageEvent(ctx);

      if (path === '/chat/messages' && request.method === 'GET') return publicChatMessages(ctx);
      if (path === '/feedback' && request.method === 'POST') return createStudentFeedback(ctx);
      if (path === '/chat/messages' && request.method === 'POST') return createPublicChatMessage(ctx);
      if (/^\/chat\/messages\/[^/]+$/.test(path) && request.method === 'DELETE') return deleteOwnPublicChatMessage(ctx, path.split('/')[3]);
      if (/^\/chat\/messages\/[^/]+\/report$/.test(path) && request.method === 'POST') return reportPublicChatMessage(ctx, path.split('/')[3]);
      if (request.method === 'GET' && path === '/app/update') return appUpdate(ctx);

      if (request.method === 'GET' && (
        path === '/' || path === '/news' || path === '/announcements' ||
        path === '/activities' || path === '/achievements'
      )) {
        const actionMap = {
          '/news': 'news',
          '/announcements': 'announcements',
          '/activities': 'activities',
          '/achievements': 'achievements',
        };
        const action = actionMap[path] || String(url.searchParams.get('action') || '').trim().toLowerCase();
        if (action === 'activities') return publicList(ctx, 'events');
        if (['news', 'announcements', 'achievements'].includes(action)) return publicList(ctx, action);
      }

      if (request.method === 'GET' && path === '/public/news') return publicList(ctx, 'news');
      if (request.method === 'GET' && path === '/public/announcements') return publicList(ctx, 'announcements');
      if (request.method === 'GET' && path === '/public/activities') return publicList(ctx, 'events');
      if (request.method === 'GET' && path === '/public/achievements') return publicList(ctx, 'achievements');
      if (request.method === 'GET' && /^\/public\/(news|activities|achievements)\/[^/]+$/.test(path)) return publicContentDetail(ctx);
      if (request.method === 'GET' && /^\/public\/students\/[^/]+$/.test(path)) return publicStudentProfile(ctx, decodeURIComponent(path.split('/')[3]));
      if (request.method === 'GET' && path === '/public/settings') return publicSettings(ctx);
      if (request.method === 'GET' && path === '/public/materials') return publicMaterials(ctx);
      if (request.method === 'GET' && /^\/media\//.test(path)) return mediaGet(ctx);

      if (path === '/auth/login' && request.method === 'POST') return login(ctx);
      if (path === '/auth/register' && request.method === 'POST') return registerStudent(ctx);
      if (path === '/auth/change-password' && request.method === 'POST') return studentChangePassword(ctx);
      if (path === '/auth/forgot-password' && request.method === 'POST') return forgotStudentPassword(ctx);
      if (path === '/auth/reset-password' && request.method === 'POST') return resetStudentPassword(ctx);
      if (path === '/auth/staff/login' && request.method === 'POST') return staffLogin(ctx);
      if (path === '/auth/staff/bootstrap' && request.method === 'POST') return staffBootstrap(ctx);
      if (path === '/auth/staff/me' && request.method === 'GET') return staffMe(ctx);
      if (path === '/auth/staff/me' && request.method === 'PATCH') return staffUpdateMe(ctx);
      if (path === '/auth/staff/change-password' && request.method === 'POST') return staffChangePassword(ctx);
      if (path === '/auth/refresh' && request.method === 'POST') return refresh(ctx);
      if (path === '/auth/logout' && request.method === 'POST') return logout(ctx);
      if (path === '/auth/me' && request.method === 'GET') return authMe(ctx);

      if (path === '/student/me' && request.method === 'GET') return studentMe(ctx);
      if (path === '/student/profile' && request.method === 'GET') return studentMe(ctx);
      if (path === '/student/semester' && request.method === 'POST') return updateStudentSemester(ctx);
      if (path === '/student/stats' && request.method === 'GET') return studentStats(ctx);
      if (path === '/student/notifications' && request.method === 'GET') return studentNotifications(ctx);
      if (path === '/student/notifications/read' && request.method === 'POST') return studentNotificationRead(ctx);
      if (path === '/student/notifications/device' && request.method === 'POST') return registerNotificationDevice(ctx);
      if (path === '/student/notifications/device' && request.method === 'DELETE') return unregisterNotificationDevice(ctx);
      if (/^\/student\/notifications\/[^/]+$/.test(path) && request.method === 'DELETE') return deleteStudentNotification(ctx, decodeURIComponent(path.split('/')[3]));

      if (path === '/semesters' && request.method === 'GET') return semesters(ctx);
      if (path === '/departments' && request.method === 'GET') return departments(ctx);
      if (path === '/subjects' && request.method === 'GET') return subjects(ctx);
      if (path === '/materials' && request.method === 'GET') return materials(ctx);
      if (path === '/exams' && request.method === 'GET') return exams(ctx);
      if (/^\/materials\/[^/]+\/file$/.test(path) && request.method === 'GET') return materialFile(ctx, path.split('/')[2]);
      if (/^\/materials\/[^/]+$/.test(path) && request.method === 'GET') return materialById(ctx, path.split('/')[2]);
      if (path === '/schedule' && request.method === 'GET') return schedule(ctx);

      if (path === '/progress' && request.method === 'GET') return progress(ctx);
      if (path === '/xp' && request.method === 'GET') return xp(ctx);
      if (path === '/badges' && request.method === 'GET') return badges(ctx);
      if (/^\/materials\/[^/]+\/progress$/.test(path) && request.method === 'POST') {
        return materialProgress(ctx, path.split('/')[2]);
      }

      if (/^\/content\/[^/]+\/[^/]+\/comments$/.test(path) && request.method === 'GET') return comments(ctx);
      if (/^\/content\/[^/]+\/[^/]+\/comments$/.test(path) && request.method === 'POST') return createComment(ctx);
      if (/^\/comments\/[^/]+\/replies$/.test(path) && request.method === 'GET') return replies(ctx);
      if (/^\/comments\/[^/]+\/replies$/.test(path) && request.method === 'POST') return createReply(ctx);
      if (/^\/content\/[^/]+\/[^/]+\/reactions$/.test(path) && request.method === 'POST') return reaction(ctx);
      if (/^\/content\/[^/]+\/[^/]+\/reactions$/.test(path) && request.method === 'DELETE') return removeReaction(ctx);
      if (/^\/comments\/[^/]+\/reactions$/.test(path) && request.method === 'POST') return commentReaction(ctx);
      if (/^\/comments\/[^/]+\/reactions$/.test(path) && request.method === 'DELETE') return removeCommentReaction(ctx);
      if (/^\/comments\/[^/]+$/.test(path) && request.method === 'DELETE') return deleteComment(ctx, path.split('/')[2]);
      if (/^\/replies\/[^/]+$/.test(path) && request.method === 'DELETE') return deleteOwnReply(ctx, path.split('/')[2]);

      if (path === '/admin/drive/sync' && request.method === 'POST') return adminDriveSync(ctx);
      if (path === '/admin/materials/upload' && request.method === 'POST') return adminUploadMaterialPdf(ctx);
      if (path === '/admin/drive/sync-status' && request.method === 'GET') return adminDriveSyncStatus(ctx);
      if (path === '/admin/media' && request.method === 'POST') return adminMediaUpload(ctx);
      if (path === '/admin/notifications' && request.method === 'GET') return adminNotifications(ctx);
      if (path === '/admin/notifications/send' && request.method === 'POST') return adminNotificationSend(ctx, null);
      if (path === '/admin/security/auth-events' && request.method === 'GET') return adminAuthEvents(ctx);
      if (/^\/admin\/students\/[^/]+\/moderator$/.test(path) && request.method === 'PATCH') return adminSetStudentModerator(ctx, path.split('/')[3]);
      if (path === '/admin/moderation/inbox' && request.method === 'GET') return adminModerationInbox(ctx);
      if (path === '/admin/moderation/chat-reports' && request.method === 'GET') return adminChatReports(ctx);
      if (path === '/admin/moderation/feedback' && request.method === 'GET') return adminFeedbackReports(ctx);
      if (/^\/admin\/moderation\/feedback\/[^/]+$/.test(path) && request.method === 'PATCH') return adminFeedbackReportUpdate(ctx, path.split('/')[4]);
      if (/^\/admin\/moderation\/chat-reports\/[^/]+$/.test(path) && request.method === 'PATCH') return adminChatReportUpdate(ctx, path.split('/')[4]);
      if (path === '/admin/moderation/comments' && request.method === 'GET') return adminModerationComments(ctx);
      if (/^\/admin\/moderation\/comments\/[^/]+$/.test(path) && request.method === 'PATCH') return adminModerationComment(ctx, path.split('/')[4]);
      if (path === '/admin/moderation/replies' && request.method === 'GET') return adminModerationReplies(ctx);
      if (/^\/admin\/moderation\/replies\/[^/]+$/.test(path) && request.method === 'PATCH') return adminModerationReply(ctx, path.split('/')[4]);
      if (/^\/admin\/moderation\/replies\/[^/]+$/.test(path) && request.method === 'DELETE') return adminDeleteReply(ctx, path.split('/')[4]);
      if (path === '/admin/dashboard/overview' && request.method === 'GET') return adminDashboardOverview(ctx);
      if (path === '/admin/analytics/overview' && request.method === 'GET') return adminUsageAnalytics(ctx);
      if (path === '/admin/security/eino-usage' && request.method === 'GET') return adminEinoUsage(ctx);
      if (path === '/admin/security/eino-monitor' && request.method === 'GET') return adminEinoMonitor(ctx);
      if (path.startsWith('/admin/')) return adminRoute(ctx);

      if (path === '/eino/chat' && request.method === 'POST') return eino(ctx);
      if (path === '/eino/chats' && request.method === 'POST') return einoConversationCreate(ctx);
      if (path === '/eino/chats' && request.method === 'GET') return einoConversationList(ctx);
      if (/^\/eino\/chats\/[^/]+\/messages$/.test(path) && request.method === 'GET') return einoConversationMessages(ctx, path.split('/')[3]);
      if (/^\/eino\/chats\/[^/]+\/messages$/.test(path) && request.method === 'POST') return einoConversationMessageAppend(ctx, path.split('/')[3]);
      if (/^\/eino\/chats\/[^/]+$/.test(path) && request.method === 'DELETE') return einoConversationDelete(ctx, path.split('/')[3]);
      if (path === '/eino/capabilities' && request.method === 'GET') return einoCapabilities(ctx);
      if (path === '/eino/models' && request.method === 'GET') return einoModels(ctx);
      if (path === '/eino/memory' && request.method === 'GET') return einoMemoryList(ctx);
      if (path === '/eino/memory' && request.method === 'POST') return einoMemoryCreate(ctx);
      if (/^\/eino\/memory\/[^/]+$/.test(path) && request.method === 'DELETE') return einoMemoryDelete(ctx, path.split('/')[3]);
      if (path === '/eino/vision' && request.method === 'POST') return einoVision(ctx);
      if (path === '/eino/ocr' && request.method === 'POST') return einoOcr(ctx);
      if (path === '/eino/stt' && request.method === 'POST') return einoStt(ctx);
      if (path === '/eino/tts' && request.method === 'POST') return einoTts(ctx);
      if (path === '/eino/image' && request.method === 'POST') return einoImage(ctx);
      if (path === '/eino/file-analysis' && request.method === 'POST') return einoFileAnalysis(ctx);
      if (path === '/eino/long-summary' && request.method === 'POST') return einoLongSummary(ctx);

      return error('NOT_FOUND', 'المسار غير موجود.', 404, requestId, cors);
      })();
      const logUsage = () => persistResourceUsage(originalEnv, metrics, request, route, response.status, Date.now() - startedAt);
      if (executionCtx?.waitUntil) executionCtx.waitUntil(logUsage()); else await logUsage();

      // Recompute the next alarm only after successful writes that can create,
      // edit, or remove scheduled content and notification work.
      const schedulerRelevantWrite = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method)
        && /^\/admin\/(news|achievements|announcements|notifications)(\/|$)/.test(path)
        && response.status < 400;
      if (schedulerRelevantWrite && originalEnv.SCHEDULER && executionCtx?.waitUntil) {
        const scheduler = originalEnv.SCHEDULER.get(originalEnv.SCHEDULER.idFromName('main'));
        executionCtx.waitUntil(scheduler.fetch('https://scheduler/reschedule', { method: 'POST' })
          .catch((e) => console.error('Scheduler reschedule after admin write failed', e)));
      }
      return response;
    } catch (e) {
      console.error(`[${requestId}]`, e);
      const response = databaseErrorResponse(e, requestId, cors);
      const logUsage = () => persistResourceUsage(originalEnv, metrics, request, metricRoute, response.status, Date.now() - startedAt);
      if (executionCtx?.waitUntil) executionCtx.waitUntil(logUsage()); else await logUsage();
      return response;
    }
  },
};
