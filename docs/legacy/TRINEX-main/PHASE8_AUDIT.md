# Phase 8 — Security and Integration Audit

## Scope
Reviewed the TRINEX Admin Flutter source against the backend files supplied in `Union-App.zip`. No production credentials were used and no live write requests were made.

## Changes in this phase

- Coalesced simultaneous session refresh requests in `ApiService`. The backend refresh token is single-use; concurrent screens now await the same in-flight rotation instead of issuing competing refresh requests.
- Added a regression test that expects two simultaneous requests with an expired session to trigger exactly one refresh and then complete with the rotated access token.
- Redacted sensitive key names in audit-event detail views. JSON metadata is parsed and recursively redacted; malformed metadata is hidden instead of being rendered raw.
- Reviewed the student search URL. The query is encoded with `Uri.encodeQueryComponent`, so spaces and reserved characters do not corrupt the API query.

## Backend contract checks

The following routes were found in the provided backend source and match the app calls: `POST /auth/staff/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/staff/change-password`, `GET /admin/students`, `GET /departments`, `GET /semesters`, `/admin/staff`, `/admin/audit-logs`, `/admin/security/auth-events`, `/admin/settings`, `/admin/notifications`, `POST /admin/notifications/send`, `POST /admin/media`, `/admin/subjects`, `/admin/materials`, `/admin/schedule`, and Drive sync/status routes.

## Validation performed

- `npm run check` in the supplied backend completed successfully (`node --check` on all backend JavaScript files).
- The Phase 7 ZIP integrity check completed without errors before this audit.
- Flutter analysis, Flutter tests, and native builds could not be executed because Flutter/Dart SDKs are not installed in this environment. The new Dart regression test is added but remains unexecuted here.
- No live API calls were made; route matching is source-level only.

## Remaining release gates

1. Run `flutter pub get`, `flutter analyze`, and `flutter test` in a Flutter-enabled environment.
2. Build and smoke-test Android, Windows, and iOS targets on their supported build hosts.
3. Verify a test account for each backend role against the deployed API; navigation visibility is not a security boundary.
4. Confirm Cloudflare R2 media storage and push-delivery worker/configuration in the deployed environment.
5. Test destructive flows (student deletion, subject/material deletion, staff deletion, staff password reset) against a disposable staging database only.

## Security note

This is an integration audit, not a penetration test or a production-readiness certification. The backend remains the source of truth for authorization.
