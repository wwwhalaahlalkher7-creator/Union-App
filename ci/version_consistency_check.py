#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
version = (root / 'apps/student/VERSION').read_text().splitlines()[0].strip()
name, build = version.split('+', 1)
app_version = (root / 'apps/student/lib/core/app_version.dart').read_text()
pubspec = (root / 'apps/student/pubspec.yaml').read_text()
readme = (root / 'README.md').read_text()
env_example = (root / '.env.example').read_text()
worker = (root / 'services/api/wrangler.toml').read_text()

checks = {
    'AppVersion matches canonical VERSION': f"static const name = '{name}';" in app_version and f'static const build = {build};' in app_version,
    'pubspec matches canonical VERSION': re.search(r'^version:\s*' + re.escape(version) + r'\s*$', pubspec, re.M) is not None,
    'README references canonical VERSION': f'`{version}`' in readme,
    'environment example APP_VERSION matches': f'APP_VERSION={name}' in env_example,
    'Worker APP_VERSION matches': f'APP_VERSION = "{name}"' in worker,
}
for label, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ' ' + label)
if not all(checks.values()):
    raise SystemExit('Version consistency check failed.')
print('VERSION CONSISTENCY CHECK PASSED')
