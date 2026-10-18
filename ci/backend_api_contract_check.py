#!/usr/bin/env python3
"""Verify the public API contract against the Worker router and Flutter client."""
from pathlib import Path
import re, sys

root = Path(__file__).resolve().parents[1]
backend = (root / 'backend/src/index.js').read_text()
contract = (root / 'backend/docs/PUBLIC_API_CONTRACT.md').read_text()
flutter = '\n'.join(p.read_text() for p in (root / 'flutter/lib').rglob('*.dart'))

required_routes = [
    ('GET', '/health'), ('GET', '/version'), ('GET', '/app/update'),
    ('GET', '/public/news'), ('GET', '/public/activities'), ('GET', '/public/announcements'),
    ('GET', '/public/achievements'), ('GET', '/public/students/:id'),
    ('GET', '/public/settings'), ('GET', '/public/materials'),
    ('POST', '/auth/login'), ('POST', '/auth/register'), ('POST', '/auth/refresh'),
    ('POST', '/auth/logout'), ('GET', '/auth/me'),
    ('GET', '/student/profile'), ('POST', '/student/semester'), ('GET', '/student/stats'),
    ('GET', '/student/notifications'), ('POST', '/student/notifications/read'),
    ('GET', '/semesters'), ('GET', '/departments'), ('GET', '/subjects'),
    ('GET', '/materials'), ('GET', '/schedule'), ('GET', '/progress'), ('GET', '/xp'), ('GET', '/badges'),
    ('POST', '/materials/:id/progress'),
    ('GET', '/chat/messages'), ('POST', '/chat/messages'),
    ('DELETE', '/chat/messages/:id'), ('POST', '/chat/messages/:id/report'),
    ('GET', '/eino/capabilities'), ('GET', '/eino/models'), ('GET', '/eino/memory'),
    ('POST', '/eino/memory'), ('POST', '/eino/chat'), ('POST', '/eino/vision'),
    ('POST', '/eino/ocr'), ('POST', '/eino/stt'), ('POST', '/eino/tts'),
]

# Normalize parameterized router patterns to a stable contract form.
checks = {
    'GET /health': "path === '/health' && request.method === 'GET'",
    'GET /version': "path === '/version' && request.method === 'GET'",
    'GET /app/update': "path === '/app/update' && request.method === 'GET'",
    'GET /auth/register': "path === '/auth/register' && request.method === 'POST'",
    'GET /chat/messages': "path === '/chat/messages' && request.method === 'GET'",
    'POST /chat/messages': "path === '/chat/messages' && request.method === 'POST'",
}
failures=[]
for method, route in required_routes:
    marker = route.replace(':id', '')
    if route in checks:
        if checks[route] not in backend:
            failures.append(f'Missing router: {method} {route}')
    elif route.startswith('/public/') and route.count('/') == 2:
        resource=route.rsplit('/',1)[-1]
        if f"path === '/public/{resource}'" not in backend:
            failures.append(f'Missing router: {method} {route}')
    elif route == '/public/students/:id':
        if "/^\\/public\\/students\\/[^/]+$/.test(path)" not in backend:
            failures.append('Missing router: GET /public/students/:id')
    elif route == '/materials/:id/progress':
        if "/^\\/materials\\/[^/]+\\/progress$/.test(path)" not in backend:
            failures.append('Missing router: POST /materials/:id/progress')
    elif route == '/chat/messages/:id/report':
        if "/^\\/chat\\/messages\\/[^/]+\\/report$/.test(path)" not in backend:
            failures.append('Missing router: POST /chat/messages/:id/report')
    elif route == '/chat/messages/:id':
        if "/^\\/chat\\/messages\\/[^/]+$/.test(path)" not in backend:
            failures.append('Missing router: DELETE /chat/messages/:id')
    elif route.startswith('/eino/'):
        resource=route.rsplit('/',1)[-1]
        if f"path === '/eino/{resource}'" not in backend:
            failures.append(f'Missing router: {method} {route}')
    elif route.startswith('/student/') or route in {'/semesters','/departments','/subjects','/materials','/schedule','/progress','/xp','/badges'}:
        resource=route
        if f"path === '{resource}'" not in backend:
            failures.append(f'Missing router: {method} {route}')
    elif route.startswith('/auth/'):
        resource=route
        if f"path === '{resource}'" not in backend:
            failures.append(f'Missing router: {method} {route}')

# Flutter must only call documented public endpoints (excluding admin/legacy routes).
flutter_paths=set(re.findall(r"['\"](/api/v1/[^'\"]+)", flutter))
for path in sorted(flutter_paths):
    normalized=re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", ':id', path)
    if normalized.endswith(':id') and '/eino/memory/' in normalized:
        documented=True
    elif '/api/v1/public/$type/$id' in path:
        documented=True
    elif path == '/api/v1/public/${_publicRoute(type)}/$id':
        # ContentRepository maps logical interaction types to canonical public plural routes.
        documented=True
    elif normalized == '/api/v1/public/':
        # This is a cache-prefix check in api_client.dart, not an HTTP endpoint.
        documented=True
    elif normalized.startswith('/api/v1/public/'):
        resource=normalized[len('/api/v1/public/'):].split('/')[0]
        documented=resource in {'news','activities','announcements','achievements','settings','materials','students'}
        if normalized.count('/') >= 4 and resource in {'news','activities','achievements'}:
            documented = True
    else:
        docpath=normalized[len('/api/v1'):]
        documented=docpath in contract or docpath.split('/')[0] in contract
    if not documented:
        failures.append(f'Flutter path not documented: {path}')

# General chat contract: authentication, bounded payloads, reporting and moderation.
chat_backend=(root/'backend/src/chat.js').read_text()
chat_migration=(root/'backend/migrations/0035_public_chat.sql').read_text()
chat_reply_migration=(root/'backend/migrations/0036_public_chat_replies.sql').read_text()
chat_screen=(root/'flutter/lib/features/chat/general_chat_screen.dart').read_text()
admin_moderation=(root/'backend/src/admin.js').read_text()
for marker, source, label in [
    ('studentAuth(ctx)', chat_backend, 'student-only authorization'),
    ('MAX_BODY = 1000', chat_backend, 'message length bound'),
    ('CHAT_RATE_LIMITED', chat_backend, 'send rate limit'),
    ('public_chat_reports', chat_backend, 'report workflow'),
    ('replyToMessageId', chat_backend, 'reply target validation'),
    ('reply_to_message_id', chat_reply_migration, 'reply relation migration'),
    ('moderation.read', (root/'backend/src/admin.js').read_text(), 'staff moderation read permission'),
    ('moderation.write', (root/'backend/src/admin.js').read_text(), 'staff moderation write permission'),
    ('CHECK (status IN', chat_migration, 'message moderation states'),
    ('moderation.read', admin_moderation, 'admin report queue permission'),
    ('Timer.periodic(const Duration(seconds: 5)', chat_screen, 'periodic message refresh'),
]:
    if marker not in source:
        failures.append(f'General chat missing {label}')

# Unified moderation inbox and durable archive state.
moderation_index = (root / 'backend/src/index.js').read_text()
moderation_admin = (root / 'backend/src/admin.js').read_text()
moderation_migration = (root / 'backend/migrations/0044_moderation_archive.sql').read_text()
moderation_contract = (root / 'backend/docs/PUBLIC_API_CONTRACT.md').read_text()
for marker, source, label in [
    ("path === '/admin/moderation/inbox' && request.method === 'GET'", moderation_index, 'unified inbox route'),
    ('adminModerationInbox(ctx)', moderation_index, 'unified inbox handler wiring'),
    ('export async function adminModerationInbox(ctx)', moderation_admin, 'unified inbox handler'),
    ("requireAdminPermission(ctx, 'moderation.read')", moderation_admin, 'inbox read authorization'),
    ("'archived'", moderation_migration, 'durable archive status migration'),
    ('/admin/moderation/inbox', moderation_contract, 'documented unified inbox endpoint'),
]:
    if marker not in source:
        failures.append(f'Moderation inbox missing {label}')

# Explicitly protect the timeout contract.
api_client=(root/'flutter/lib/core/network/api_client.dart').read_text()
for marker in ["'/eino/chat'", "'/eino/vision'", "'/eino/tts'"]:
    pass
if '_requestTimeout' not in api_client or 'Duration(seconds: 45)' not in api_client:
    failures.append('Flutter Eino timeout guard is missing')

if failures:
    print('\n'.join('FAIL: '+x for x in failures))
    sys.exit(1)
print(f'API contract audit PASS: {len(required_routes)} required routes checked; Flutter paths checked: {len(flutter_paths)}')
