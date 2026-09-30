from pathlib import Path
import re, sqlite3, sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

version_values = []
for line in (ROOT / 'flutter/VERSION').read_text(encoding='utf-8').splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        continue
    value = re.sub(r'\s+#.*$', '', stripped).strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+\+\d+', value):
        errors.append(f'Invalid VERSION: {stripped}')
    else:
        version_values.append(value)
version = version_values[0] if len(version_values) == 1 else ''
if len(version_values) != 1:
    errors.append('VERSION must contain exactly one version value')
m = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)\+(\d+)', version)
if not m:
    errors.append(f'Invalid VERSION: {version}')
else:
    semver = '.'.join(m.group(i) for i in range(1, 4))
    code = int(m.group(4))
    pub = (ROOT / 'flutter/pubspec.yaml').read_text(encoding='utf-8')
    av = (ROOT / 'flutter/lib/core/app_version.dart').read_text(encoding='utf-8')
    gradle = (ROOT / 'flutter/android/app/build.gradle').read_text(encoding='utf-8')
    if f'version: {semver}+{code}' not in pub:
        errors.append('pubspec version mismatch')
    if f"static const name = '{semver}';" not in av or f'static const build = {code};' not in av:
        errors.append('app_version.dart mismatch')
    if 'applicationId = "com.leoassociation.app"' not in gradle:
        errors.append('Android applicationId changed')
    if 'versionCode = flutter.versionCode' not in gradle or 'versionName = flutter.versionName' not in gradle:
        errors.append('Android version linkage changed')

# Apply every migration in lexical order to a clean SQLite database.
try:
    con = sqlite3.connect(':memory:')
    migrations = sorted((ROOT / 'backend/migrations').glob('*.sql'))
    for path in migrations:
        con.executescript(path.read_text(encoding='utf-8'))
    table_count = con.execute("select count(*) from sqlite_master where type='table'").fetchone()[0]
    if table_count < 1:
        errors.append('No tables produced by migrations')
except Exception as exc:
    errors.append(f'Migration check failed: {exc}')

# Production security invariants.
backend_source = '\n'.join(p.read_text(encoding='utf-8') for p in (ROOT / 'backend/src').rglob('*.js'))
if 'const ADMIN_ROLE_PERMISSIONS = Object.freeze({' not in backend_source:
    errors.append('Missing centralized admin role permission map')
if 'if(!ADMIN_ROLE_IDS.has(role))' not in backend_source or 'if(!ADMIN_ROLE_IDS.has(nextRole))' not in backend_source:
    errors.append('Staff role allowlist validation is missing')
if "allowedOrigins.length === 0 ? '*'" in backend_source:
    errors.append('CORS must not fall back to wildcard in production')

# Admin API safety invariants.
if 'const ADMIN_SELECT_COLUMNS = {' not in backend_source:
    errors.append('Admin CRUD must use an explicit safe SELECT projection')
if "const CONTENT_TABLES = Object.freeze(new Set(['news', 'events', 'activities', 'announcements', 'achievements']))" not in backend_source:
    errors.append('Admin content lifecycle contract is missing')
if "DELETE FROM ${table} WHERE id=?" not in backend_source:
    errors.append('Admin content DELETE must hard-delete by id')
if "DELETE FROM announcements WHERE id=?" not in backend_source:
    errors.append('Admin announcements DELETE must hard-delete by id')
student_projection_match = re.search(r"students:\s*'([^']+)'", backend_source[backend_source.find('const ADMIN_SELECT_COLUMNS'):])
if not student_projection_match:
    errors.append('Missing admin student projection')
else:
    student_projection = student_projection_match.group(1)
    if 'auth_secret_hash,' in student_projection or 'auth_secret_salt' in student_projection or 'auth_secret_algo' in student_projection:
        errors.append('Admin student projection exposes authentication secret columns')
    if 'AS registered' not in student_projection:
        errors.append('Admin student projection lost the safe derived registration flag')
if "mode:'hard_delete'" not in backend_source:
    errors.append('Admin hard-delete audit contract is missing')
if "mode:'hard_delete'" not in backend_source:
    errors.append('Admin content hard-delete audit contract is missing')

# Active operational source must not contain retired provider/ad architecture.
legacy_tokens = ('ad-manager', 'airtable')
for base in (ROOT / 'flutter/lib', ROOT / 'website/admin', ROOT / 'backend/src'):
    for path in base.rglob('*'):
        if path.suffix not in {'.dart', '.js', '.ts', '.html', '.css'}:
            continue
        text = path.read_text(encoding='utf-8', errors='ignore').lower()
        for token in legacy_tokens:
            if token in text:
                errors.append(f'Legacy operational reference: {path} -> {token}')
                break

required = [
    ROOT / 'README.md',
    ROOT / 'CONTRIBUTING.md',
    ROOT / 'docs/ARCHITECTURE.md',
    ROOT / 'docs/CONFIGURATION.md',
    ROOT / 'docs/RELEASE.md',
    ROOT / 'ci/release_check.py',
    ROOT / 'ci/verify_project.py',
]
for path in required:
    if not path.exists():
        errors.append(f'Missing required release file: {path.relative_to(ROOT)}')

if errors:
    print('FINAL RELEASE CHECK FAILED')
    for error in errors:
        print(' -', error)
    sys.exit(1)

print(f'FINAL RELEASE CHECK PASSED: {version}; migrations={table_count} tables; applicationId=com.leoassociation.app')
print('NOTE: Flutter SDK/build/signing must be validated in CI or a Flutter release environment.')
