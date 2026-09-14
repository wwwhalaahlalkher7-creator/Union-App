from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
worker = (root / 'backend/src/index.js').read_text(encoding='utf-8')
migration = (root / 'backend/migrations/0015_auth_hardening.sql').read_text(encoding='utf-8')

checks = {
    'IP rate-limit constants': all(x in worker for x in [
        'AUTH_IP_WINDOW_SECONDS', 'AUTH_IP_LOGIN_LIMIT', 'AUTH_IP_REFRESH_LIMIT'
    ]),
    'hashed IP persistence': "const ipHash = await sha256(ip)" in worker and 'ip_hash' in migration,
    'login rate limiting': "authIpRateLimit(ctx, 'student_login'" in worker and "authIpRateLimit(ctx, 'staff_login'" in worker,
    'refresh rate limiting': "authIpRateLimit(ctx, 'refresh'" in worker,
    'atomic refresh rotation': "UPDATE sessions SET revoked_at = CURRENT_TIMESTAMP WHERE id = ? AND refresh_token_hash = ? AND revoked_at IS NULL" in worker,
    'refresh reuse detection': "AUTH_REFRESH_REUSED" in worker and "refresh_reuse_or_invalid" in worker,
    'disabled account refresh guard': "AUTH_ACCOUNT_DISABLED" in worker and "SELECT active FROM staff_users" in worker and "SELECT active FROM students" in worker,
    'staff user_id login': "lower(su.user_id) = ?" in worker and "user_id TEXT NOT NULL" in (root / 'backend/migrations/0018_staff_user_id.sql').read_text(encoding='utf-8'),
    'Eino auto model': "configuredModel.toLowerCase() === 'auto'" in worker and "EINO_MODEL = \"auto\"" in (root / 'backend/wrangler.toml').read_text(encoding='utf-8'),
    'rate-limit migration': 'CREATE TABLE IF NOT EXISTS auth_rate_limits' in migration and 'CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_window' in migration,
    'session expiry index': 'idx_sessions_expiry' in migration,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('AUTH HARDENING CHECK FAILED: ' + ', '.join(failed))

print('AUTH HARDENING CHECK PASSED: IP limits, atomic refresh rotation, reuse detection, disabled-account guards, and D1 indexes')
