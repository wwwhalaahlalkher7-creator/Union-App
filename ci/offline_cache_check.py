#!/usr/bin/env python3
"""Static guard for the offline-first architecture."""
from pathlib import Path
import sys

api = Path('flutter/lib/core/network/api_client.dart').read_text(encoding='utf-8')
app = Path('flutter/lib/app/app.dart').read_text(encoding='utf-8')
cache = Path('flutter/lib/core/network/offline_cache.dart').read_text(encoding='utf-8')

checks = {
    'persistent offline cache': 'OfflineCache.instance.write' in api and 'OfflineCache.instance.read' in api,
    'offline state': 'OfflineState.instance.markOffline' in api and 'OfflineState.instance.markOnline' in api,
    'offline banner': 'OfflineBanner' in app,
    'cache pruning': '_maxEntries' in cache and '_prune' in cache,
    'eino excluded from cache': "p.contains('/eino/')" in api,
    'auth excluded from cache': "p.contains('/auth/')" in api,
    'per-student cache namespace': 'student:${studentNumber.trim()}|$uri' in api and 'public|$uri' in api,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('OFFLINE CACHE CHECK FAILED')
    print('\n'.join(f'- {name}' for name in failed))
    sys.exit(1)

print('OFFLINE CACHE CHECK PASSED')
for name in checks:
    print(f'PASS {name}')
