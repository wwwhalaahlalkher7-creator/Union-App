from pathlib import Path
import tomllib

ROOT = Path(__file__).resolve().parents[1]
index = (ROOT / 'services/api/src/index.js').read_text()
scheduler = (ROOT / 'services/api/src/scheduler.js').read_text()
wrangler_text = (ROOT / 'services/api/wrangler.toml').read_text()
migration = (ROOT / 'services/api/migrations/0040_notification_schedule_runs.sql').read_text()
wrangler = tomllib.loads(wrangler_text)

bindings = wrangler.get('durable_objects', {}).get('bindings', [])
class_binding = next((item for item in bindings if item.get('name') == 'SCHEDULER'), None)
migrations = wrangler.get('migrations', [])
legacy_migration = next((item for item in migrations if item.get('tag') == 'v1'), None)

checks = {
    'stable production class is exported from scheduler module': 'export class TrinexScheduler extends DurableObject' in scheduler,
    'Worker entrypoint re-exports the stable class': "export { TrinexScheduler } from './scheduler.js';" in index,
    'Durable Object binding retains stable class name': bool(class_binding and class_binding.get('class_name') == 'TrinexScheduler'),
    'existing DO migration tag and SQLite class are retained': bool(legacy_migration and 'TrinexScheduler' in legacy_migration.get('new_sqlite_classes', [])),
    'scheduler alarm materializes announcements and dispatches push': 'materializeDueAnnouncements' in scheduler and 'dispatchPushNotifications(this.env, 40)' in scheduler,
    'scheduler re-arms after relevant admin writes': 'Scheduler reschedule after admin write failed' in index,
    'hourly recovery cron is configured': '0 * * * *' in wrangler.get('triggers', {}).get('crons', []),
    'announcement fan-out idempotency migration exists': 'CREATE TABLE IF NOT EXISTS notification_schedule_runs' in migration,
}

for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + name)
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('DURABLE SCHEDULER CHECK FAILED: ' + ', '.join(failed))
print(f'DURABLE SCHEDULER CHECK PASSED: {len(checks)} checks')
