#!/usr/bin/env python3
"""Ensure the requested native-admin release version is reflected in project metadata."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
expected = '1.1.0+1'
pubspec = (ROOT / 'apps/admin/pubspec.yaml').read_text(encoding='utf-8')
readme = (ROOT / 'README.md').read_text(encoding='utf-8')
admin_readme = (ROOT / 'apps/admin/README.md').read_text(encoding='utf-8')
if not re.search(r'^version:\s*' + re.escape(expected) + r'\s*$', pubspec, re.M):
    raise SystemExit(f'Admin pubspec version must be {expected}')
if f'`{expected}`' not in readme or f'`{expected}`' not in admin_readme:
    raise SystemExit('Admin version must be documented in both repository and app README files')
print(f'ADMIN VERSION CHECK PASSED: {expected} (tag v1.1.0)')
