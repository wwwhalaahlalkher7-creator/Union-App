from pathlib import Path
import re, sqlite3, sys

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = ROOT / 'flutter'
BACKEND = ROOT / 'backend'
DASHBOARD = ROOT / 'website/admin'

errors=[]

# Version source of truth
version_values=[]
for line in (FLUTTER/'VERSION').read_text(encoding='utf-8').splitlines():
    stripped=line.strip()
    if not stripped or stripped.startswith('#'): continue
    value=re.sub(r'\s+#.*$', '', stripped).strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+\+\d+', value): errors.append(f'Invalid VERSION: {stripped}')
    else: version_values.append(value)
version=version_values[0] if len(version_values)==1 else ''
if len(version_values)!=1: errors.append('VERSION must contain exactly one version value')
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
legacy_tokens=('ad-manager','commercial ads','airtable')
for base in (FLUTTER/'lib', DASHBOARD, BACKEND/'src'):
    for p in base.rglob('*'):
        if p.suffix not in {'.dart','.js','.ts','.html','.css'}: continue
        text=p.read_text(encoding='utf-8',errors='ignore').lower()
        for token in legacy_tokens:
            if token in text:
                errors.append(f'Legacy/commercial reference in active source: {p} -> {token}')
                break

# Release config sanity: production builds must require explicit release signing.
gradle=(FLUTTER/'android/app/build.gradle').read_text(encoding='utf-8')
if 'signingConfig = hasReleaseSigning ? signingConfigs.release : signingConfigs.debug' in gradle:
    errors.append('Release build must not fall back to debug signing')

# Production security invariants.
backend_source = '\n'.join(p.read_text(encoding='utf-8') for p in (BACKEND / 'src').rglob('*.js'))
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
if "UPDATE ${table} SET status='archived'" not in backend_source:
    errors.append('Admin content DELETE must archive by status')
student_projection_match = re.search(r"students:\s*'([^']+)'", backend_source[backend_source.find('const ADMIN_SELECT_COLUMNS'):])
if not student_projection_match:
    errors.append('Missing admin student projection')
else:
    student_projection = student_projection_match.group(1)
    if 'auth_secret_hash,' in student_projection or 'auth_secret_salt' in student_projection or 'auth_secret_algo' in student_projection:
        errors.append('Admin student projection exposes authentication secret columns')
    if 'AS registered' not in student_projection:
        errors.append('Admin student projection lost the safe derived registration flag')
if "WHERE id=? AND active=1" not in backend_source:
    errors.append('Soft-deletable admin records must not fall through to hard delete')

# Canonical maintenance/release documentation must exist.
for rel in ('README.md', 'CONTRIBUTING.md', 'docs/ARCHITECTURE.md', 'docs/CONFIGURATION.md', 'docs/RELEASE.md'):
    if not (ROOT / rel).exists(): errors.append(f'Missing canonical documentation: {rel}')

if errors:
    print('RELEASE CHECK FAILED')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'Release candidate checks passed: {version}; migrations={tables} tables; applicationId=com.leoassociation.app')
