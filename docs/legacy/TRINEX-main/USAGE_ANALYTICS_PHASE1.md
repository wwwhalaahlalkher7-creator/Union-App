# TRINEX-Admin — Usage analytics phase 1

Added the Arabic `التحليلات والاستخدام` page. It requests only the authorized aggregated endpoint `GET /api/v1/admin/analytics/overview?days=...` and presents event totals, daily/weekly active sessions, new sessions, app-vs-website sessions, popular sections, event types, and failed operations.

The page is visible only to `super_admin` in the client navigation. The backend endpoint independently enforces `superadmin.read`; UI visibility is not treated as a security boundary. The UI explicitly shows a deployment-related error rather than fabricated sample values if the endpoint or migration is unavailable.

The corresponding backend, D1 migration, website instrumentation and student-app route tracking are delivered separately in the updated Union-App archive. Apply migration `0039_usage_analytics.sql` and deploy the Worker before expecting live data. This archive was not deployed; Flutter analyze/build and live API checks still need to run in CI.
