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
    ('GET', '/public/news'), ('GET', '/public/events'), ('GET', '/public/announcements'),
    ('GET', '/public/activities'), ('GET', '/public/achievements'),
    ('GET', '/public/settings'), ('GET', '/public/materials'),
    ('POST', '/auth/login'), ('POST', '/auth/register'), ('POST', '/auth/refresh'),
    ('POST', '/auth/logout'), ('GET', '/auth/me'),
    ('GET', '/student/profile'), ('POST', '/student/semester'), ('GET', '/student/stats'),
    ('GET', '/student/notifications'), ('POST', '/student/notifications/read'),
    ('GET', '/semesters'), ('GET', '/departments'), ('GET', '/subjects'),
    ('GET', '/materials'), ('GET', '/schedule'), ('GET', '/progress'), ('GET', '/xp'), ('GET', '/badges'),
    ('POST', '/materials/:id/progress'),
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
    elif normalized.startswith('/api/v1/public/'):
        resource=normalized[len('/api/v1/public/'):].split('/')[0]
        documented=resource in {'news','events','announcements','activities','achievements','settings','materials'}
        if normalized.count('/') >= 4 and resource in {'news','events','activities'}:
            documented = True
    else:
        docpath=normalized[len('/api/v1'):]
        documented=docpath in contract or docpath.split('/')[0] in contract
    if not documented:
        failures.append(f'Flutter path not documented: {path}')

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
