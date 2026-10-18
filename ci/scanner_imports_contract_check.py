import os
from pathlib import Path

root = Path(__file__).resolve().parents[1]

# This contract spans the API project and the separately distributed Flutter
# admin app. Prefer an explicit path, then the conventional sibling checkout;
# if the admin repository is not checked out in this workspace, skip only the
# cross-project source assertion rather than failing an otherwise valid API CI.
scanner_relpath = Path('lib/src/features/imports/scanner_import_dialog.dart')
scanner_candidates = []
configured_admin_root = os.environ.get('TRINEX_ADMIN_ROOT')
if configured_admin_root:
    scanner_candidates.append(Path(configured_admin_root) / scanner_relpath)
scanner_candidates.append(root.parent / 'TRINEX-admin' / scanner_relpath)
scanner_candidates.extend(
    candidate / scanner_relpath
    for candidate in root.parent.iterdir()
    if candidate.is_dir() and candidate.name not in {root.name, 'node_modules'}
)
scanner_source_path = next((candidate for candidate in scanner_candidates if candidate.is_file()), None)
admin = (root / 'backend/src/admin.js').read_text(encoding='utf-8')
index = (root / 'backend/src/index.js').read_text(encoding='utf-8')
migration = (root / 'backend/migrations/0042_scanner_imports.sql').read_text(encoding='utf-8')
wrangler = (root / 'backend/wrangler.toml').read_text(encoding='utf-8')

checks = {
    'import session schema': 'CREATE TABLE IF NOT EXISTS import_operations' in migration,
    'final review snapshot schema': 'reviewed_json TEXT NOT NULL' in migration,
    'reversible before/after snapshots': 'before_json TEXT' in migration and 'after_json TEXT NOT NULL' in migration,
    'one-hour expiry cleanup cron': '"0 * * * *"' in wrangler and "status='expired',reviewed_json='[]'" in index,
    'OCR endpoint uses dedicated OCR.space API': 'ocrSpaceFromFile(' in admin and 'OCR_SPACE_API_KEY' in admin,
    'provider free-tier size cap is enforced': 'providerMaxBytes = 1024 * 1024' in admin and 'IMPORT_FILE_OVER_PROVIDER_LIMIT' in admin,
    'student imports do not update existing students': "STUDENT_NUMBER_DUPLICATE" in admin and "INSERT INTO students" in admin,
    'student duplicate scope includes department and semester': 'WHERE department_id=? AND current_semester_id=?' in admin,
    'overlap predicate is used': 'sch.start_time < ? AND sch.end_time > ?' in admin,
    'manual schedule CRUD validates overlap': 'SCHEDULE_TIME_CONFLICT' in admin and 'const conflict = await queryOne(ctx.env' in admin,
    'post-approval review edit endpoint': "action === 'records'" in admin and 'import_review_updated' in admin,
    'super-admin rollback enforcement': "if(!isSuper) return error('FORBIDDEN','التراجع عن الاستيراد متاح لمدير النظام فقط.'" in admin,
    'rollback blocks changed rows': 'modified_after_import' in admin,
}
if scanner_source_path is not None:
    checks['Flutter compresses/rasterizes uploads locally'] = "_prepareOcrUpload(bytes, file.name, mime)" in scanner_source_path.read_text(encoding='utf-8')
else:
    print('SKIP Flutter scanner source assertion: set TRINEX_ADMIN_ROOT or check out TRINEX-admin beside this repository.')

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed:
    raise SystemExit(1)
