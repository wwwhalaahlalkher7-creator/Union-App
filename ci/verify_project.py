from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
flutter = ROOT / 'flutter'
version_file = flutter / 'VERSION'
pubspec = flutter / 'pubspec.yaml'
app_version = flutter / 'lib/core/app_version.dart'

version_values = []
for line in version_file.read_text(encoding='utf-8').splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        continue
    value = re.sub(r'\s+#.*$', '', stripped).strip()
    if re.fullmatch(r'\d+\.\d+\.\d+\+\d+', value):
        version_values.append(value)
    else:
        raise SystemExit(f'Invalid VERSION: {stripped!r}')
if len(version_values) != 1:
    raise SystemExit('VERSION must contain exactly one version value')
version = version_values[0]
m = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)\+(\d+)', version)
if not m:
    raise SystemExit(f'Invalid VERSION: {version!r}')
name = '.'.join(m.group(i) for i in range(1, 4))
build = m.group(4)

pub = pubspec.read_text(encoding='utf-8')
if f'version: {name}+{build}' not in pub:
    raise SystemExit('pubspec.yaml is out of sync with VERSION')

av = app_version.read_text(encoding='utf-8')
if f"static const name = '{name}';" not in av or f'static const build = {build};' not in av:
    raise SystemExit('app_version.dart is out of sync with VERSION')

for path in list((flutter / 'lib').rglob('*')) + list((ROOT / 'backend' / 'src').rglob('*')):
    if path.suffix not in {'.dart', '.js'}:
        continue
    text = path.read_text(encoding='utf-8', errors='ignore').lower()
    if 'ad-manager' in text or 'commercial ads' in text:
        raise SystemExit(f'Commercial ad reference found in active source: {path}')

print(f'Project verification passed: {version}')
