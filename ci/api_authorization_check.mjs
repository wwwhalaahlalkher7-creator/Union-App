import assert from 'node:assert/strict';
import { adminPermission } from '../backend/src/admin.js';
import { ADMIN_ROLE_PERMISSIONS } from '../backend/src/admin/config.js';
import { hasAdminPermission } from '../backend/src/admin/permissions.js';
import { readFile } from 'node:fs/promises';

// Role matrix: ensure no operational role silently inherits another role's scope.
const expected = {
  super_admin: ['dashboard.read', 'content.read', 'content.write', 'academic.read', 'academic.write', 'moderation.read', 'moderation.write', 'notifications.read', 'notifications.write', 'superadmin.read', 'superadmin.write'],
  content_manager: ['dashboard.read', 'content.read', 'content.write'],
  academic_manager: ['dashboard.read', 'academic.read', 'academic.write'],
  moderator: ['dashboard.read', 'moderation.read', 'moderation.write', 'notifications.read', 'notifications.write'],
};
assert.deepEqual(Object.keys(ADMIN_ROLE_PERMISSIONS).sort(), Object.keys(expected).sort(), 'Unexpected admin role added/removed; review its permission scope');
for (const [role, permissions] of Object.entries(expected)) {
  for (const permission of ['dashboard.read','content.read','content.write','academic.read','academic.write','moderation.read','moderation.write','notifications.read','notifications.write','superadmin.read','superadmin.write']) {
    assert.equal(hasAdminPermission(role, permission), permissions.includes(permission), `${role} permission mismatch: ${permission}`);
  }
}
assert.equal(hasAdminPermission('unknown_role', 'content.read'), false, 'Unknown roles must deny by default');

// Route-to-permission matrix: reads and mutations must not be downgraded to public access.
const routes = [
  ['/admin/news', 'GET', 'content.read'], ['/admin/news', 'POST', 'content.write'],
  ['/admin/events/123', 'DELETE', 'content.write'],
  ['/admin/students', 'GET', 'academic.read'], ['/admin/students/123', 'PATCH', 'academic.write'],
  ['/admin/materials', 'GET', 'academic.read'], ['/admin/materials/123', 'DELETE', 'academic.write'],
  ['/admin/moderation/comments', 'GET', 'moderation.read'], ['/admin/moderation/comments/123', 'PATCH', 'moderation.write'],
  ['/admin/notifications', 'GET', 'notifications.read'], ['/admin/notifications/send', 'POST', 'notifications.write'],
  ['/admin/announcements', 'GET', 'notifications.read'], ['/admin/announcements', 'POST', 'notifications.write'],
  ['/admin/settings', 'GET', 'superadmin.read'], ['/admin/settings', 'PUT', 'superadmin.write'],
  ['/admin/staff', 'GET', 'superadmin.read'], ['/admin/staff/123', 'DELETE', 'superadmin.write'],
  ['/admin/security/auth-events', 'GET', 'superadmin.read'],
  ['/admin/security/eino-monitor', 'GET', 'superadmin.read'],
  ['/admin/security/eino-usage', 'GET', 'dashboard.read'],
  ['/admin/drive/sync-status', 'GET', 'academic.read'], ['/admin/drive/sync', 'POST', 'academic.write'],
  ['/admin/learning-events', 'GET', 'notifications.read'], ['/admin/learning-events', 'POST', 'notifications.write'],
  ['/admin/dashboard/overview', 'GET', 'dashboard.read'],
];
for (const [path, method, permission] of routes) {
  assert.equal(adminPermission(path, method), permission, `${method} ${path} must require ${permission}`);
}

// Directly routed admin handlers must retain their own authorization guard, because
// they bypass adminRoute's central guard in backend/src/index.js.
const admin = await readFile(new URL('../backend/src/admin.js', import.meta.url), 'utf8');
const drive = await readFile(new URL('../backend/src/drive.js', import.meta.url), 'utf8');
const media = await readFile(new URL('../backend/src/media.js', import.meta.url), 'utf8');
const learning = await readFile(new URL('../backend/src/learning_events.js', import.meta.url), 'utf8');
const index = await readFile(new URL('../backend/src/index.js', import.meta.url), 'utf8');
for (const [label, source, fn, guard] of [
  ['admin auth events', admin, 'adminAuthEvents', 'adminRouteAuthOnly'],
  ['admin notifications', admin, 'adminNotifications', 'adminRouteAuthOnly'],
  ['admin notification send', admin, 'adminNotificationSend', 'adminRouteAuthOnly'],
  ['Eino usage dashboard', admin, 'adminEinoUsage', 'requireAdminPermission'],
  ['Eino monitor dashboard', admin, 'adminEinoMonitor', 'requireAdminPermission'],
  ['Drive sync', drive, 'adminDriveSync', 'adminDriveAuth'],
  ['media upload', media, 'adminMediaUpload', 'requireAdminPermission'],
  ['learning-event admin', learning, 'adminLearningEvents', 'requireAdminPermission'],
]) {
  const start = source.indexOf(`function ${fn}(`);
  assert.notEqual(start, -1, `Missing direct admin handler: ${fn}`);
  const next = source.indexOf('\nexport ', start + 10);
  const block = source.slice(start, next < 0 ? undefined : next);
  assert.ok(block.includes(guard), `${label} is missing its authorization guard`);
}
assert.match(index, /path\.startsWith\('\/admin\/'\)\s*&&\s*!\['GET', 'POST', 'PUT', 'PATCH', 'DELETE'\]\.includes\(request\.method\)/, 'Admin API must reject unsupported HTTP methods');

// Student Eino data reads/writes must always be scoped to the authenticated student.
const eino = await readFile(new URL('../backend/src/eino.js', import.meta.url), 'utf8');
for (const fn of ['einoConversationMessages', 'einoConversationMessageAppend', 'einoConversationDelete', 'einoMemoryList', 'einoMemoryDelete']) {
  const start = eino.indexOf(`function ${fn}(`);
  assert.notEqual(start, -1, `Missing student-scoped Eino handler: ${fn}`);
  const next = eino.indexOf('\nexport ', start + 10);
  const block = eino.slice(start, next < 0 ? undefined : next);
  assert.ok(block.includes('getEinoStudent(ctx)'), `${fn} must require an authenticated student`);
}
console.log(`API authorization audit: PASS (${routes.length} route-permission cases, ${Object.keys(expected).length} role scopes, direct-handler guards)`);
