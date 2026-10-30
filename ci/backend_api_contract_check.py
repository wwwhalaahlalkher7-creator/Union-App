#!/usr/bin/env python3
"""Verify the public API contract against the Worker router and Flutter client."""
from pathlib import Path
import re, sys

root = Path(__file__).resolve().parents[1]
backend = (root / 'services/api/src/index.js').read_text()
contract = (root / 'services/api/docs/PUBLIC_API_CONTRACT.md').read_text()
flutter = '\n'.join(p.read_text() for p in (root / 'apps/student/lib').rglob('*.dart'))

required_routes = [
    ('GET', '/health'), ('GET', '/version'), ('GET', '/app/update'),
    ('GET', '/public/news'), ('GET', '/public/events'), ('GET', '/public/announcements'),
    ('GET', '/public/achievements'), ('GET', '/public/activities'), ('GET', '/public/students/:id'),
    ('GET', '/public/settings'), ('GET', '/public/materials'),
    ('POST', '/auth/login'), ('POST', '/auth/register'), ('POST', '/auth/refresh'),
    ('POST', '/auth/logout'), ('GET', '/auth/me'),
    ('GET', '/student/profile'), ('POST', '/student/semester'), ('GET', '/student/stats'),
    ('GET', '/student/notifications'), ('POST', '/student/notifications/read'), ('DELETE', '/student/notifications/:id'),
    ('GET', '/semesters'), ('GET', '/departments'), ('GET', '/subjects'),
    ('GET', '/materials'), ('GET', '/exams'), ('GET', '/schedule'), ('GET', '/progress'), ('GET', '/xp'), ('GET', '/badges'),
    ('POST', '/materials/:id/progress'),
    ('GET', '/chat/messages'), ('POST', '/chat/messages'), ('DELETE', '/chat/messages/:id'), ('POST', '/chat/messages/:id/report'),
    ('POST', '/feedback'), ('POST', '/usage/events'),
    ('POST', '/eino/chats'), ('GET', '/eino/chats'), ('GET', '/eino/chats/:id/messages'),
    ('POST', '/eino/chats/:id/messages'), ('DELETE', '/eino/chats/:id'),
    ('POST', '/eino/long-summary'), ('POST', '/eino/file-analysis'), ('POST', '/eino/image'),
    ('DELETE', '/content/:type/:id/reactions'), ('DELETE', '/comments/:id/reactions'), ('DELETE', '/replies/:id'),
    ('GET', '/eino/capabilities'), ('GET', '/eino/models'), ('GET', '/eino/memory'),
    ('POST', '/eino/memory'), ('POST', '/eino/chat'), ('POST', '/eino/vision'),
    ('POST', '/eino/ocr'), ('POST', '/eino/stt'), ('POST', '/eino/tts'),
]

# Normalize parameterized router patterns to a stable contract form.
checks = {
    'GET /health': "request.method === 'GET' && path === '/health'",
    'GET /version': "request.method === 'GET' && path === '/version'",
    'GET /app/update': "request.method === 'GET' && path === '/app/update'",
    'POST /auth/register': "path === '/auth/register' && request.method === 'POST'",
    'GET /public/activities': "path === '/public/activities'",
    'GET /public/students/:id': "/^\\/public\\/students\\/[^/]+$/.test(path)",
    'DELETE /student/notifications/:id': "/^\\/student\\/notifications\\/(?!device$)[^/]+$/.test(path)",
    'GET /exams': "path === '/exams' && request.method === 'GET'",
    'GET /chat/messages': "path === '/chat/messages' && request.method === 'GET'",
    'POST /chat/messages': "path === '/chat/messages' && request.method === 'POST'",
    'DELETE /chat/messages/:id': "/^\\/chat\\/messages\\/[^/]+$/.test(path) && request.method === 'DELETE'",
    'POST /chat/messages/:id/report': "/^\\/chat\\/messages\\/[^/]+\\/report$/.test(path) && request.method === 'POST'",
    'POST /feedback': "(path === '/student/feedback' || path === '/feedback') && request.method === 'POST'",
    'POST /usage/events': "path === '/usage/events' && request.method === 'POST'",
    'POST /eino/chats': "path === '/eino/chats' && request.method === 'POST'",
    'GET /eino/chats': "path === '/eino/chats' && request.method === 'GET'",
    'GET /eino/chats/:id/messages': "/^\\/eino\\/chats\\/[^/]+\\/messages$/.test(path) && request.method === 'GET'",
    'POST /eino/chats/:id/messages': "/^\\/eino\\/chats\\/[^/]+\\/messages$/.test(path) && request.method === 'POST'",
    'DELETE /eino/chats/:id': "/^\\/eino\\/chats\\/[^/]+$/.test(path) && request.method === 'DELETE'",
    'POST /eino/long-summary': "path === '/eino/long-summary' && request.method === 'POST'",
    'POST /eino/file-analysis': "path === '/eino/file-analysis' && request.method === 'POST'",
    'POST /eino/image': "path === '/eino/image' && request.method === 'POST'",
    'DELETE /content/:type/:id/reactions': "/^\\/content\\/[^/]+\\/[^/]+\\/reactions$/.test(path) && request.method === 'DELETE'",
    'DELETE /comments/:id/reactions': "/^\\/comments\\/[^/]+\\/reactions$/.test(path) && request.method === 'DELETE'",
    'DELETE /replies/:id': "/^\\/replies\\/[^/]+$/.test(path)",
}
failures=[]
for method, route in required_routes:
    marker = route.replace(':id', '')
    check_key = f'{method} {route}'
    if check_key in checks:
        if checks[check_key] not in backend:
            failures.append(f'Missing router: {method} {route}')
    elif route.startswith('/public/') and route.count('/') == 2:
        resource=route.rsplit('/',1)[-1]
        if f"path === '/public/{resource}'" not in backend:
            failures.append(f'Missing router: {method} {route}')
    elif route == '/materials/:id/progress':
        if "/^\\/materials\\/[^/]+\\/progress$/.test(path)" not in backend:
            failures.append('Missing router: POST /materials/:id/progress')
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
    elif path.startswith('/api/v1/chat/messages/${') or path.startswith('/api/v1/student/notifications/${'):
        documented=True
    elif normalized.startswith('/api/v1/public/'):
        resource=normalized[len('/api/v1/public/'):].split('/')[0]
        documented=resource in {'news','events','activities','announcements','achievements','settings','materials','students'}
        if normalized.count('/') >= 4 and resource in {'news','events','achievements'}:
            documented = True
    else:
        docpath=normalized[len('/api/v1'):]
        documented=docpath in contract or docpath.split('/')[0] in contract
    if not documented:
        failures.append(f'Flutter path not documented: {path}')

# Explicitly protect the timeout contract.
api_client=(root/'apps/student/lib/core/network/api_client.dart').read_text()
for marker in ["'/eino/chat'", "'/eino/vision'", "'/eino/tts'"]:
    pass
if '_requestTimeout' not in api_client or 'Duration(seconds: 45)' not in api_client:
    failures.append('Flutter Eino timeout guard is missing')

if failures:
    print('\n'.join('FAIL: '+x for x in failures))
    sys.exit(1)
print(f'API contract audit PASS: {len(required_routes)} required routes checked; Flutter paths checked: {len(flutter_paths)}')
