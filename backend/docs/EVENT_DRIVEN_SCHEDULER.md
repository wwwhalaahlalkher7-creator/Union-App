# Event-driven publication and notification scheduler

## What changed

- Replaced the every-minute Worker Cron (`* * * * *`) with a daily Cron at `03:00 UTC` for 90-day analytics retention cleanup and low-frequency alarm recovery.
- Added the SQLite-backed Durable Object `TrinexScheduler`, whose single alarm is set to the next due publication or notification queue item.
- Successful writes under `/api/v1/admin/news`, `/achievements`, `/announcements`, and `/notifications` request alarm recalculation.
- On an alarm, due drafts are published using the existing status rules, the existing notification queue materializes due announcements and dispatches at most 50 pending items, and the next alarm is calculated. Backlogs are revisited after five seconds; transient scheduler-level failures retry after one minute. Per-item notification failures retain the existing capped retry policy.
- When no eligible work is pending, the Durable Object deletes its alarm instead of polling D1.

## Deployment notes

- `wrangler.toml` now declares the `SCHEDULER` Durable Object binding and migration tag `v1` (`new_sqlite_classes = ["TrinexScheduler"]`). Deploy through Wrangler so the Durable Object class migration is applied.
- No D1 schema changes are included. Existing content and notification tables are reused.
- After deployment, the first successful relevant admin write initializes/recalculates the alarm. The daily recovery signal also recalculates it, which protects schedules already stored before the new alarm-based scheduler is first activated.
- The Worker must keep the existing `FCM_SERVICE_ACCOUNT_JSON` secret configured to dispatch push notifications. In-app notifications can still be processed without it. If FCM is configured after deployment, the next relevant admin write or daily recovery recalculates pending push work.

## Verification performed

- `node --check` passed for `src/index.js` and `src/scheduler.js`.
- `npm run check` passed for all backend JavaScript files.
- Live Cloudflare/D1/FCM integration tests were not run in this environment; deploy to a staging Worker first and verify scheduled news/achievements, in-app notifications, push dispatch, and retry behavior before production rollout.
