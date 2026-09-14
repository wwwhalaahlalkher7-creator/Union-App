#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = ROOT / 'flutter'

def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')

pubspec = read('flutter/pubspec.yaml')
auth = read('flutter/lib/core/storage/auth_storage.dart')
api = read('flutter/lib/core/network/api_client.dart')
client = read('flutter/lib/core/network/authenticated_client.dart')

checks = [
    ('secure storage dependency', 'flutter_secure_storage:' in pubspec),
    ('secure storage implementation', 'FlutterSecureStorage' in auth),
    ('tokens stored securely', "_secureStorage.write(key: _access" in auth and "_secureStorage.write(key: _refresh" in auth),
    ('profile stored securely', "_secureStorage.write(key: _profile" in auth),
    ('legacy token migration', 'SharedPreferences.getInstance()' in auth and '_migrateLegacyPreferences' in auth),
    ('legacy copies removed', 'await prefs.remove(_access)' in auth and 'await prefs.remove(_refresh)' in auth),
    ('async access token', 'await authStorage?.accessToken' in api),
    ('async refresh token', 'await authStorage?.refreshToken' in api),
    ('secure AuthStorage factory', 'await AuthStorage.create()' in client),
    ('no direct SharedPreferences auth construction', 'AuthStorage(prefs)' not in '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in FLUTTER.rglob('*.dart'))),
]
failed = [name for name, ok in checks if not ok]
if failed:
    print('FLUTTER SECURE STORAGE CHECK FAILED:')
    for item in failed: print(' -', item)
    sys.exit(1)
print('FLUTTER SECURE STORAGE CHECK PASSED')
for name, _ in checks: print(' -', name)
