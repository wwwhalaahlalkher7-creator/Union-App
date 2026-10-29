# TRINEX-Admin Phase 6 — Notifications and media

## Implemented

- Arabic RTL notifications page backed by `GET /admin/notifications?limit=100`.
- Confirmed send/update targeting for published announcements via `POST /admin/notifications/send` with `announcementId`.
- UI messaging distinguishes server-side queueing from actual push delivery.
- Media upload page uses the existing `POST /admin/media` multipart contract (`file`).
- JPEG, PNG, and WebP are accepted by the UI; images larger than 3 MB are rejected client-side. Backend validation remains authoritative.
- Multipart upload uses the current staff session and performs a single token refresh/retry after HTTP 401.
- Returned media URL can be copied and used in the image URL field for news, events, and achievements.
- Navigation visibility is aligned to the current backend role permissions.

## Explicit limitations

- Push notifications are only queued by the endpoint; delivery depends on the deployment's dispatch worker/provider configuration.
- Media upload requires the backend's media bucket/R2 binding and quota tables to be configured.
- Image upload is a separate screen; no inline image picker was added to the content dialog.
- No media deletion UI or attachment ownership workflow was added.
- Learning-event CRUD is not implemented in this phase.
- Flutter analyzer, tests, and native builds were not run because Flutter/Dart SDK is unavailable in the editing environment.
