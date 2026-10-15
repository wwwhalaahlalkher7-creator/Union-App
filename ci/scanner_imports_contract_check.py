from pathlib import Path

root = Path(__file__).resolve().parents[1]
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
    'Flutter compresses/rasterizes uploads locally': "_prepareOcrUpload(bytes, file.name, mime)" in (root.parent / 'TRINEX-admin/lib/src/features/imports/scanner_import_dialog.dart').read_text(encoding='utf-8'),
    'student imports do not update existing students': "STUDENT_NUMBER_DUPLICATE" in admin and "INSERT INTO students" in admin,
    'student duplicate scope includes department and semester': 'WHERE department_id=? AND current_semester_id=?' in admin,
    'overlap predicate is used': 'sch.start_time < ? AND sch.end_time > ?' in admin,
    'manual schedule CRUD validates overlap': 'SCHEDULE_TIME_CONFLICT' in admin and 'const conflict = await queryOne(ctx.env' in admin,
    'post-approval review edit endpoint': "action === 'records'" in admin and 'import_review_updated' in admin,
    'super-admin rollback enforcement': "if(!isSuper) return error('FORBIDDEN','التراجع عن الاستيراد متاح لمدير النظام فقط.'" in admin,
    'rollback blocks changed rows': 'modified_after_import' in admin,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed:
    raise SystemExit(1)
