import { error } from '../core.js';
import { staffAuth } from '../auth.js';
import { ADMIN_ROLE_PERMISSIONS } from './config.js';

/**
 * Checks a role without touching the request/session layer.
 * Keeping this pure makes authorization rules easy to test.
 */
export function hasAdminPermission(roleId, permissionName) {
  const allowed = ADMIN_ROLE_PERMISSIONS[roleId] || [];
  return allowed.includes('*') || allowed.includes(permissionName);
}

/**
 * Authenticates the staff session and checks the requested permission.
 */
export async function requireAdminPermission(ctx, permissionName) {
  const auth = await staffAuth(ctx);
  if (auth.response) return auth;

  if (!auth.session.staff_user_id || auth.session.staff_active !== 1) {
    return {
      response: error(
        'STAFF_AUTH_REQUIRED',
        'صلاحيات الإدارة مطلوبة.',
        403,
        ctx.requestId,
        ctx.cors,
      ),
    };
  }

  if (!hasAdminPermission(auth.session.staff_role_id, permissionName)) {
    return {
      response: error(
        'FORBIDDEN',
        'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
        403,
        ctx.requestId,
        ctx.cors,
      ),
    };
  }

  return auth;
}
