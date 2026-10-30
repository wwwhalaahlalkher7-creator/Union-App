# TRINEX Platform 2.0.4 — Durable Object Scheduler Deployment Fix

Date: 2026-10-30
App version: 2.0.4+3

## Root cause

The production Cloudflare Worker still has Durable Objects backed by the class `TrinexScheduler`. During the Union-App to Monorepo merge, the Worker entrypoint stopped exporting that class and `services/api/wrangler.toml` lost the `SCHEDULER` binding and its original Durable Object migration declaration. Cloudflare therefore rejected the Worker version with error 10064 before publishing it.

## Changes

- Restored `services/api/src/scheduler.js` and exported the same class name: `TrinexScheduler`.
- Re-exported `TrinexScheduler` from `services/api/src/index.js`.
- Restored `SCHEDULER` Durable Object binding and the original migration declaration (`tag = "v1"`, `new_sqlite_classes = ["TrinexScheduler"]`). The class name and tag are deliberately unchanged to preserve the existing production namespace and storage.
- Adapted the scheduler to Monorepo's current notification implementation (`dispatchPushNotifications`) instead of importing the legacy Union-App `notifications.js` module.
- Restored rescheduling after successful admin writes affecting news, achievements, announcements, and notifications.
- Added an hourly recovery trigger while preserving the existing every-minute Cron used for push dispatch and Eino indexing.
- Added migration `0040_notification_schedule_runs.sql` so already-processed announcements, including those with zero eligible recipients, are not repeatedly fanned out.
- Added `ci/durable_scheduler_check.py` and updated the minute-Cron assertion to allow the additional hourly recovery Cron.

## Validation performed

- Worker JavaScript syntax: all `services/api/src/*.js` passed `node --check`.
- Wrangler TOML parsed successfully; `SCHEDULER` binding and original `v1` class migration are present.
- SQLite migration chain: 40 migrations applied successfully to a fresh in-memory database.
- Scheduler SQL preflight: announcement materialization and next-alarm queries executed against the migrated schema.
- Durable scheduler checks: 8/8 passed.
- Push dispatch checks: 9/9 passed.
- Project verification, release check, and final release check passed at 2.0.4+3.
- Backend API contract and integrity checks passed; backend schema audit passed with 52 tables and 192 indexes.

## Deployment notes

- Existing remote D1 migrations 0035–0039 were already applied successfully in the reported deployment. Do not reset D1 or delete migration history.
- On the next CI deployment, Wrangler should apply only the new D1 migration `0040_notification_schedule_runs.sql`.
- The existing Durable Object class name and migration tag are preserved. Do not add a `delete-class` migration or rename `TrinexScheduler`.
- This patch was validated statically and against local SQLite. A remote Worker deployment and Cloudflare Durable Object runtime execution have not been performed from this environment.
- Flutter was not changed by this patch; no APK was built.
