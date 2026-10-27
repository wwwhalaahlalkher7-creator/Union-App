from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'services/api/src/notification_dispatch.js').read_text()
index = (ROOT / 'services/api/src/index.js').read_text()
wrangler = (ROOT / 'services/api/wrangler.toml').read_text()
docs = (ROOT / 'services/api/docs/push-notifications-setup.md').read_text()
checks = {
    'service account supplied through Worker secret': 'env.FCM_SERVICE_ACCOUNT_JSON' in source,
    'FCM HTTP v1 endpoint': 'fcm.googleapis.com/v1/projects/' in source,
    'bounded queue batch': 'Math.min(100, Number(limit) || 40)' in source,
    'retry backoff and terminal failure': 'retryMinutes(attempt)' in source and 'MAX_ATTEMPTS' in source,
    'invalid token deactivation': "detail?.errorCode === 'UNREGISTERED'" in source and 'SET active=0' in source,
    'no device token logging': 'console.log(row.token)' not in source and 'console.error(row.token)' not in source,
    'scheduled Worker entrypoint': 'async scheduled(' in index and 'dispatchPushNotifications(env, 40)' in index,
    'minute cron trigger': 'crons = ["* * * * *"]' in wrangler,
    'client setup and real-device validation documented': 'real Android device' in docs and 'required values are missing' in docs,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ' ' + name)
if failed:
    raise SystemExit('PUSH DISPATCH CHECK FAILED: ' + ', '.join(failed))
print(f'PUSH DISPATCH CHECK PASSED: {len(checks)} checks')
