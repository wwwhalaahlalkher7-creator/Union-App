#!/usr/bin/env python3
"""Static contract/security guard for the student password-recovery flow."""
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
auth = (ROOT / 'backend/src/auth.js').read_text(encoding='utf-8')
router = (ROOT / 'backend/src/index.js').read_text(encoding='utf-8')
contract = (ROOT / 'backend/docs/PUBLIC_API_CONTRACT.md').read_text(encoding='utf-8')
screen = (ROOT / 'flutter/lib/features/auth/forgot_password_screen.dart').read_text(encoding='utf-8')
loc = (ROOT / 'flutter/lib/core/localization/app_localizations.dart').read_text(encoding='utf-8')
apps = (ROOT / 'backend/App Script/Code.gs').read_text(encoding='utf-8')
migration = (ROOT / 'backend/migrations/0030_student_password_recovery.sql').read_text(encoding='utf-8')
errors = []

required_auth = [
    "path === '/auth/forgot-password' && request.method === 'POST'",
    "path === '/auth/reset-password' && request.method === 'POST'",
]
for marker in required_auth:
    if marker not in router:
        errors.append(f'Missing recovery router: {marker}')
for route in ('POST /auth/forgot-password', 'POST /auth/reset-password'):
    if route not in contract:
        errors.append(f'Missing API contract route: {route}')

# Generic recovery response must not expose account existence.
if "RECOVERY_STUDENT_NOT_FOUND" in auth:
    errors.append('Recovery endpoint still exposes RECOVERY_STUDENT_NOT_FOUND')
if "NO_RECOVERY_EMAIL" in auth:
    errors.append('Recovery endpoint still exposes NO_RECOVERY_EMAIL')
if 'return ok(ctx, { sent: true, expiresInSeconds: 600 });' not in auth:
    errors.append('Generic recovery success response is missing')

# Atomic one-time code consumption and atomic attempt counting.
if not re.search(r'UPDATE password_reset_codes\s+SET used_at = CURRENT_TIMESTAMP\s+WHERE id = \? AND used_at IS NULL', auth, re.S):
    errors.append('Recovery code is not atomically claimed')
if not re.search(r'UPDATE password_reset_codes\s+SET attempts = attempts \+ 1\s+WHERE id = \?[^`]+attempts < 5', auth, re.S):
    errors.append('Recovery attempt counter is not atomically incremented')
if "UPDATE sessions SET revoked_at=CURRENT_TIMESTAMP WHERE student_id=? AND revoked_at IS NULL" not in auth:
    errors.append('Password reset does not revoke existing sessions')
if 'timingSafeEqualHex' not in auth or "await sha256(code)" not in auth:
    errors.append('Recovery code comparison is not protected by the expected hash/timing-safe flow')
if 'datetime(\'now\',\'+10 minutes\')' not in auth:
    errors.append('Recovery code expiry is not 10 minutes')

# Flutter UX: resend cooldown, validation, and translated strings.
for marker in ('Timer.periodic', '_resendSeconds', 'resendRecoveryCode', "'/api/v1/auth/forgot-password'", "'/api/v1/auth/reset-password'"):
    if marker not in screen:
        errors.append(f'Flutter recovery guard missing: {marker}')
for key in ('forgotPassword', 'forgotPasswordHelp', 'recoveryCode', 'sendRecoveryCode', 'resendRecoveryCode', 'recoverySent', 'recoveryResendWait', 'recoverySending', 'recoveryResetting'):
    for locale in ("'ar':", "'en':", "'fr':"):
        start = loc.find(locale)
        if start < 0 or loc.find("'%s':" % key, start, loc.find("\n    '" if start > 0 else '', start + 1) if False else len(loc)) < 0:
            # Check key globally per locale block below instead of relying on map delimiters.
            pass
# Use locale block boundaries.
blocks = {}
for locale in ('ar', 'en', 'fr'):
    start = loc.find(f"'{locale}': {{")
    end = loc.find("\n    },", start)
    blocks[locale] = loc[start:end if end != -1 else len(loc)]
for locale, block in blocks.items():
    for key in ('forgotPassword', 'forgotPasswordHelp', 'recoveryCode', 'sendRecoveryCode', 'resendRecoveryCode', 'recoverySent', 'recoveryResendWait', 'recoverySending', 'recoveryResetting'):
        if f"'{key}':" not in block:
            errors.append(f'Missing {key} localization for {locale}')

# Worker must own recovery logic; Apps Script is only the authenticated Gmail bridge.
for marker in ('function doPost(e)', 'requireEmailToken', 'sendRecoveryEmail', 'MailApp.sendEmail'):
    if marker not in apps:
        errors.append(f'Apps Script recovery component missing: {marker}')
if "redirect: 'manual'" not in auth:
    errors.append('Recovery email adapter must preserve POST across Apps Script redirects')
for marker in ('script.google.com', 'script.googleusercontent.com', 'UNTRUSTED_REDIRECT'):
    if marker not in auth:
        errors.append(f'Recovery adapter redirect guard missing: {marker}')
if 'HtmlService.createHtmlOutput(JSON.stringify(result))' in apps:
    errors.append('Apps Script recovery bridge should return plain JSON, not an HTML wrapper')

# Migration must contain the recovery table and indexes.
for marker in ('CREATE TABLE IF NOT EXISTS password_reset_codes', 'code_hash', 'expires_at', 'attempts', 'used_at'):
    if marker not in migration:
        errors.append(f'Recovery migration missing: {marker}')

if errors:
    print('PASSWORD RECOVERY CHECK FAILED')
    for error in errors:
        print(' -', error)
    sys.exit(1)

print('PASSWORD RECOVERY CHECK PASSED: router, contract, anti-enumeration, atomic code use, rate/attempt guards, session revocation, Flutter UX/localization, Apps Script and migration')
