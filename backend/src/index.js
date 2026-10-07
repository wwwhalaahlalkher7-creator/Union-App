import { databaseErrorResponse, error } from './core.js';
import { publicVersion, appUpdate, health, publicContentDetail, publicList, publicMaterials, publicSettings } from './public.js';
import { mediaGet, adminMediaUpload } from './media.js';
import {
  login, registerStudent, studentChangePassword, forgotStudentPassword, resetStudentPassword, staffLogin, staffBootstrap, staffMe, staffChangePassword,
  refresh, logout, authMe,
} from './auth.js';
import {
  studentMe, updateStudentSemester, studentStats, studentNotifications, studentNotificationRead,
  registerNotificationDevice, unregisterNotificationDevice,
} from './student.js';
import {
  semesters, departments, subjects, materials, materialFile, materialById, schedule,
  progress, xp, badges, materialProgress,
} from './academic.js';
import {
  comments, createComment, replies, createReply, reaction, removeReaction, commentReaction, removeCommentReaction, deleteComment,
} from './interactions.js';
import {
  adminNotifications, adminNotificationSend,
  adminAuthEvents, adminModerationComments, adminModerationComment, adminModerationReplies, adminModerationReply, adminDeleteReply, adminDashboardOverview,
  adminEinoUsage, adminRoute,
} from './admin.js';
import { adminDriveSync, adminDriveSyncStatus } from './drive.js';
import { learningEvents, learningEvent, completeLearningEvent, adminLearningEvents } from './learning_events.js';
import {
  eino, einoCapabilities, einoModels, einoMemoryList, einoMemoryCreate, einoMemoryDelete,
  einoConversationCreate, einoConversationList, einoConversationMessages, einoConversationMessageAppend, einoConversationDelete,
  einoVision, einoOcr, einoStt, einoTts,
} from './eino.js';

export default {
  async fetch(request, env) {
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
      const ctx = { request, env, url, path, requestId, cors };

      if (request.method === 'GET' && path === '/health') return health(ctx);
      if (request.method === 'GET' && path === '/version') return publicVersion(ctx);
      if (request.method === 'GET' && path === '/app/update') return appUpdate(ctx);

      if (request.method === 'GET' && (
        path === '/' || path === '/news' || path === '/announcements' ||
        path === '/events' || path === '/achievements'
      )) {
        const actionMap = {
          '/news': 'news',
          '/announcements': 'announcements',
          '/events': 'events',
          '/achievements': 'achievements',
        };
        const action = actionMap[path] || String(url.searchParams.get('action') || '').trim().toLowerCase();
        if (['news', 'announcements', 'events', 'achievements'].includes(action)) {
          return publicList(ctx, action);
        }
      }

      if (request.method === 'GET' && path === '/public/news') return publicList(ctx, 'news');
      if (request.method === 'GET' && path === '/public/announcements') return publicList(ctx, 'announcements');
      if (request.method === 'GET' && path === '/public/events') return publicList(ctx, 'events');
      if (request.method === 'GET' && path === '/public/achievements') return publicList(ctx, 'achievements');
      if (request.method === 'GET' && /^\/public\/(news|events|achievements)\/[^/]+$/.test(path)) return publicContentDetail(ctx);
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
      if (path === '/learning-events' && request.method === 'GET') return learningEvents(ctx);
      if (/^\/learning-events\/[^/]+$/.test(path) && request.method === 'GET') return learningEvent(ctx, path.split('/')[2]);
      if (/^\/learning-events\/[^/]+\/complete$/.test(path) && request.method === 'POST') return completeLearningEvent(ctx, path.split('/')[2]);

      if (path === '/semesters' && request.method === 'GET') return semesters(ctx);
      if (path === '/departments' && request.method === 'GET') return departments(ctx);
      if (path === '/subjects' && request.method === 'GET') return subjects(ctx);
      if (path === '/materials' && request.method === 'GET') return materials(ctx);
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

      if (path === '/admin/drive/sync' && request.method === 'POST') return adminDriveSync(ctx);
      if (path === '/admin/drive/sync-status' && request.method === 'GET') return adminDriveSyncStatus(ctx);
      if (path === '/admin/media' && request.method === 'POST') return adminMediaUpload(ctx);
      if (path === '/admin/notifications' && request.method === 'GET') return adminNotifications(ctx);
      if (path === '/admin/notifications/send' && request.method === 'POST') return adminNotificationSend(ctx, null);
      if (path === '/admin/learning-events' && request.method === 'GET') return adminLearningEvents(ctx);
      if (path === '/admin/learning-events' && request.method === 'POST') return adminLearningEvents(ctx);
      if (/^\/admin\/learning-events\/[^/]+$/.test(path)) return adminLearningEvents(ctx, path.split('/')[3]);
      if (path === '/admin/security/auth-events' && request.method === 'GET') return adminAuthEvents(ctx);
      if (path === '/admin/moderation/comments' && request.method === 'GET') return adminModerationComments(ctx);
      if (/^\/admin\/moderation\/comments\/[^/]+$/.test(path) && request.method === 'PATCH') return adminModerationComment(ctx, path.split('/')[4]);
      if (path === '/admin/moderation/replies' && request.method === 'GET') return adminModerationReplies(ctx);
      if (/^\/admin\/moderation\/replies\/[^/]+$/.test(path) && request.method === 'PATCH') return adminModerationReply(ctx, path.split('/')[4]);
      if (/^\/admin\/moderation\/replies\/[^/]+$/.test(path) && request.method === 'DELETE') return adminDeleteReply(ctx, path.split('/')[4]);
      if (path === '/admin/dashboard/overview' && request.method === 'GET') return adminDashboardOverview(ctx);
      if (path === '/admin/security/eino-usage' && request.method === 'GET') return adminEinoUsage(ctx);
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

      return error('NOT_FOUND', 'المسار غير موجود.', 404, requestId, cors);
    } catch (e) {
      console.error(`[${requestId}]`, e);
      return databaseErrorResponse(e, requestId, cors);
    }
  },
};
