# Usage resource metrics and student moderation — Phase 2

## Resource analytics
- Worker API request totals, response duration and 5xx errors by normalized route.
- D1 prepared statement/batch operation counts, plus row metadata where Cloudflare D1 returns it. The telemetry insert itself is included in the D1-operation total.
- R2 reads, writes and deletes observed in the application media subsystem; bytes read/written are included when available.
- Current storage and monthly upload quota counters come from the application's `media_quota` ledger.
- Three top normalized API routes are shown separately for server requests, D1 operations and R2 operations. This is intentionally route-level rather than identifying individual students. To reduce free-tier D1 overhead, ordinary API requests are sampled at 10% and weighted by 10; any request that touches the instrumented R2 media subsystem is recorded at 100%. Server/D1 totals are estimates; instrumented R2 operation/byte totals are complete.
- Telemetry retains route, method, status, duration and counters only; it does not persist account IDs, IPs, user-agent strings, request bodies or message content. Resource rows older than 90 days are cleaned by the scheduled Worker.

### Measurement caveats
These application-side counters are not Cloudflare account billing data and do not expose Worker CPU milliseconds or static hosting usage. R2 storage only reflects media tracked by the application ledger. Exact account-wide usage requires a separate Cloudflare Analytics/API integration and a narrowly scoped credential.

## Student supervisors
- Migration `0040_student_moderators_and_resource_usage.sql` adds `students.is_moderator` and the resource telemetry table.
- A permitted admin can grant/revoke student supervisor status from each student card in TRINEX-Admin → Students. The backend writes an audit entry.
- A student supervisor sees delete actions in contextual menus for other students' public-chat messages, comments and replies. Regular students see delete only for their own content.
- Server authorization is authoritative; hiding the menu is only the UI layer. The delete endpoints re-check the student's current moderator flag.
- Staff role `moderator` is retired from the permission map and assignable role selector. Legacy staff accounts with that role no longer have privileged permissions. The old standalone moderation page is removed from admin navigation.

## Deployment order
1. Apply migration `0040_student_moderators_and_resource_usage.sql` to the configured D1 database.
2. Deploy the updated Worker backend.
3. Build/release the updated student Flutter app and the TRINEX-Admin APK.
4. Open Analytics after API requests begin to accumulate. Initial values may be zero until telemetry rows exist.

No production deployment is performed by this change package.
