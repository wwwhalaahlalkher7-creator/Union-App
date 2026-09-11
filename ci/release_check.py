from pathlib import Path
import re, sqlite3, sys

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = ROOT / 'flutter'
BACKEND = ROOT / 'backend'
DASHBOARD = ROOT / 'dashboard'

errors=[]

# Version source of truth
version=(FLUTTER/'VERSION').read_text(encoding='utf-8').strip()
m=re.fullmatch(r'(\d+)\.(\d+)\.(\d+)\+(\d+)', version)
if not m: errors.append(f'Invalid VERSION: {version}')
else:
    semver='.'.join(m.group(i) for i in range(1,4)); code=int(m.group(4))
    pub=(FLUTTER/'pubspec.yaml').read_text(encoding='utf-8')
    av=(FLUTTER/'lib/core/app_version.dart').read_text(encoding='utf-8')
    if f'version: {semver}+{code}' not in pub: errors.append('pubspec version mismatch')
    if f"static const name = '{semver}';" not in av or f'static const build = {code};' not in av: errors.append('app_version.dart mismatch')
    gradle=(FLUTTER/'android/app/build.gradle').read_text(encoding='utf-8')
    if 'applicationId = "com.leoassociation.app"' not in gradle: errors.append('Android applicationId changed')
    if 'versionCode = flutter.versionCode' not in gradle or 'versionName = flutter.versionName' not in gradle: errors.append('Android version linkage changed')

# Sequential migration smoke test
try:
    con=sqlite3.connect(':memory:')
    for p in sorted((BACKEND/'migrations').glob('*.sql')):
        con.executescript(p.read_text(encoding='utf-8'))
    tables=con.execute("select count(*) from sqlite_master where type='table'").fetchone()[0]
    if tables < 1: errors.append('Migration smoke test produced no tables')
except Exception as e:
    errors.append(f'Migration smoke test failed: {e}')

# Source policy: no operational legacy providers / commercial ads.
legacy_tokens=('ad-manager','commercial ads','google apps script','airtable')
for base in (FLUTTER/'lib', DASHBOARD, BACKEND/'src'):
    for p in base.rglob('*'):
        if p.suffix not in {'.dart','.js','.ts','.html','.css'}: continue
        text=p.read_text(encoding='utf-8',errors='ignore').lower()
        for token in legacy_tokens:
            if token in text:
                errors.append(f'Legacy/commercial reference in active source: {p} -> {token}')
                break

# Release config sanity: debug signing is permitted only as a CI/test fallback,
# but must be explicitly documented as NOT production signing.
gradle=(FLUTTER/'android/app/build.gradle').read_text(encoding='utf-8')
if 'signingConfig = signingConfigs.debug' in gradle:
    print('WARNING: release build currently uses debug signing; RC is test-installable, NOT production/Play signed.')

# Release metadata must exist.
meta=ROOT/'docs/RELEASE_CANDIDATE_V1.md'
if not meta.exists(): errors.append('Missing docs/RELEASE_CANDIDATE_V1.md')

if errors:
    print('RELEASE CHECK FAILED')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'Release candidate checks passed: {version}; migrations={tables} tables; applicationId=com.leoassociation.app')
