#!/usr/bin/env python3
"""Check CI/release workflow references stay aligned with the repository layout."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ci = (ROOT / '.github/workflows/ci.yml').read_text(encoding='utf-8')
release = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
provider = (ROOT / 'ci/eino_provider_check.py').read_text(encoding='utf-8')

required = [
    ROOT / '.github/workflows/ci.yml',
    ROOT / '.github/workflows/release.yml',
]
for path in required:
    if not path.exists():
        raise SystemExit(f'Missing required workflow: {path}')

if '.github/workflows/deploy.yml' in provider or '.github/workflows/deploy.yml' in (ROOT / 'docs/DEPLOYMENT.md').read_text(encoding='utf-8'):
    raise SystemExit('Stale deploy.yml reference remains')

for action, version in {
    'actions/checkout': '@v7',
    'actions/setup-node': '@v7',
    'actions/setup-java': '@v6',
    'actions/upload-artifact': '@v7',
}.items():
    if f'{action}{version}' not in ci + release:
        raise SystemExit(f'Expected {action}{version} in CI/release workflows')

if 'actions/download-artifact@v8' not in release:
    raise SystemExit('Release workflow must use download-artifact@v8')

if 'SamKirkland/FTP-Deploy-Action@v4.4.0' not in ci:
    raise SystemExit('CI workflow must use FTP-Deploy-Action@v4.4.0 for website deployment')

if 'SamKirkland/FTP-Deploy-Action@v4.4.0' in release:
    raise SystemExit('Production app release must not deploy the website')

if 'npx wrangler deploy' not in ci:
    raise SystemExit('CI workflow must contain the backend deployment path')

if 'npx wrangler deploy' in release:
    raise SystemExit('Production app release must not deploy the backend')

if 'releases/latest/download/Union-App.apk' not in (ROOT / 'website/download.html').read_text(encoding='utf-8'):
    raise SystemExit('Download page must use the stable GitHub latest APK URL')

if 'downloads/release.json' in (ROOT / 'website/download.html').read_text(encoding='utf-8'):
    raise SystemExit('Download page must not depend on website-side release.json')

if 'dangerous-clean-slate: true' in ci + release:
    raise SystemExit('Production website deployment must not use dangerous-clean-slate: true')

print('Workflow consistency check passed')
