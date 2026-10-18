# Usage analytics — phase 1

## Included
- Website page views and tab-session starts from `website/analytics.js`.
- Native app screen views for the main allowlisted routes.
- Anonymous ingestion at `POST /api/v1/usage/events`.
- Admin aggregate report at `GET /api/v1/admin/analytics/overview?days=7` (1–30 days, `superadmin.read`).
- D1 migration `0039_usage_analytics.sql`.
- TRINEX-Admin dashboard page for active sessions, event volume, platform split, popular sections, event types and failed operations.

## Privacy boundaries
- The clients create a random anonymous session token; the API stores only its SHA-256 hash.
- No account/student/staff IDs, IP addresses, user-agent strings, URL query strings, content IDs, search terms, message bodies, file contents, passwords or auth tokens are recorded as analytics fields.
- The API accepts only allowlisted platform, event and section values, limits events to 60 per anonymous session per minute, and exposes aggregates only to an authorized super administrator.
- The backend scheduled task purges events and sessions older than 90 days when its daily UTC cleanup trigger runs.
- Telemetry is best-effort; network failures must never block app or website usage.

## Deployment order
1. Apply the new D1 migration `0039_usage_analytics.sql` in the existing Cloudflare D1 migration flow.
2. Deploy the updated Worker/backend.
3. Publish the updated static website so `analytics.js` is served and included by the HTML pages.
4. Build and install the updated student app and TRINEX-Admin APK.
5. Open several pages/screens, then check TRINEX-Admin → التحليلات والاستخدام.

Do not expect data before migration and backend deployment. Existing historical activity is not reconstructed; the report starts collecting after deployment. This package has not been deployed to production, and live API / Flutter runtime verification remains required.


## Resource usage and student moderators (migration 0040)
- `resource_usage_events` records normalized API route, status, duration, executed D1 statement/batch counts, D1 row read/write metadata and instrumented R2 operations/bytes. No student IDs, request bodies, IPs or user agents are stored. Events older than 90 days are purged by the scheduled Worker.
- Admin analytics exposes aggregate server request counts, average response time, 5xx errors, D1 operations/row counts, R2 operation/byte counts, the application's current media storage ledger, and top three normalized API routes for server/D1/R2 use. These are operational estimates and are not Cloudflare billing/account-level usage reports.
- `students.is_moderator` is a separate student privilege. Super admins can grant/revoke it from the Students page. The backend independently checks this flag before allowing deletion of other students' comments, replies or public chat messages.
- The old staff `moderator` role is no longer granted permissions or shown as an assignable role in TRINEX-Admin.


## Measurement limits
The resource panel measures API routes observed by this Worker and R2 operations performed through the instrumented media paths. D1 statement/batch execution counts are counted at runtime; D1 row metadata is reported where the D1 result exposes it. Current storage is read from the app's `media_quota` ledger. These measurements do not expose Cloudflare account billing, Worker CPU milliseconds, static-site hosting requests, or R2 objects created outside the app's media subsystem. Exact provider usage requires a separate Cloudflare Analytics/API integration with a narrowly scoped credential.


## Measurement limits
The resource panel measures API routes observed by this Worker and R2 operations performed through the instrumented media paths. D1 statement/batch execution counts are counted at runtime; D1 row metadata is reported where the D1 result exposes it. Current storage is read from the app's `media_quota` ledger. These measurements do not expose Cloudflare account billing, Worker CPU milliseconds, static-site hosting requests, or R2 objects created outside the app's media subsystem. Exact provider usage requires a separate Cloudflare Analytics/API integration with a narrowly scoped credential.

Resource telemetry samples 10% of ordinary API requests with a weight of 10 to reduce the extra D1 write load; any request that performs an instrumented R2 operation is always recorded with weight 1. Server/D1 totals are therefore estimates, while R2 operation/byte totals for instrumented media routes are complete.
