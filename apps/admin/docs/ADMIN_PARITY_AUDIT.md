# TRINEX-Admin — Admin Capability Parity Audit

This document maps the legacy `Union-App/website/admin` capabilities to the native Flutter admin and the existing TRINEX API. The website admin directory is removed from the delivered project; the public website and backend source remain in place.

## Native screens and API connections

| Legacy capability | Flutter destination | Backend contract | Status in source |
|---|---|---|---|
| Dashboard / overview counts | Overview | `GET /admin/dashboard/overview` | Connected; includes an independent `/health` status check |
| Students | Users → Students | `/admin/students`, `/departments`, `/semesters` | CRUD and active-state controls present |
| Staff / roles | Users → Staff | `/admin/staff` | CRUD, role assignment, active-state, password reset are present; server permissions remain authoritative |
| News | Content → News | `/admin/news` | CRUD, status, dates, metadata and image upload/link supported |
| Activities / events | Content → Events | `/admin/activities` (maps to backend `events`) | Corrected route mapping; CRUD and event metadata supported |
| Achievements | Content → Achievements | `/admin/achievements` | CRUD, date, badge, highlights and image URL/upload supported; backend creates/refreshes linked notification drafts |
| Announcements | Content → Announcements | `/admin/announcements` | CRUD, type, audience IDs, publish/expiry dates and status supported |
| Academic subjects | Academic workspace | `/admin/subjects` | CRUD present |
| Study materials | Academic workspace | `/admin/materials` | CRUD and Drive sync status present; direct upload of a new Drive PDF is not provided by the legacy API/UI either |
| Schedules | Academic workspace | `/admin/schedule` | CRUD present; backend creates/refreshes linked notification drafts for meaningful schedule changes |
| Google Drive sync | Academic workspace | `/admin/drive/sync`, `/admin/drive/sync-status` | Connected; action requires confirmation |
| Comments / replies | Moderation | `/admin/moderation/comments`, `/admin/moderation/replies` | Status moderation and reply deletion present |
| Student suggestions/general reports and public chat reports | Unified Suggestions & Reports inbox (chat is a dedicated record type) | `/admin/moderation/feedback`, `/admin/moderation/chat-reports` | One searchable/filterable page; each source retains its own status and actions, including chat message hide/keep |
| Notifications | Notifications | `/admin/notifications`, `/admin/notifications/send`, `/admin/announcements/:id` | Create published or scheduled notifications, search/filter, edit, delete, display publish/expiry times, and separately confirm target-list preparation |
| Media upload | Content editor and Media | `POST /admin/media` | Added upload from content editor; JPEG/PNG/WebP, 3 MB limit, server validates and returns URL |
| Audit log and authentication events | Security | `/admin/audit-logs`, `/admin/security/auth-events` | Read-only; sensitive fields redacted in detail view |
| Eino usage/monitoring | Eino monitor | `/admin/security/eino-monitor` | Added provider/task summaries, request statuses, latency, quota limits, recent telemetry and privacy notice |
| Site display settings | Settings | `/admin/settings` | Restricted to `public.*` and `Logo`, matching the legacy adapter's safe settings scope |
| Staff account / password | Account | `/auth/staff/change-password`, `/auth/logout` | Connected |

## Notification workflow

The backend source may create or refresh linked notification records when schedule/material/achievement data changes. The Flutter notification screen no longer creates ordinary notification drafts or exposes approve/unpublish controls. It creates a normal notification as published, or marks it scheduled when the publish time is in the future. Generated academic-workflow drafts retain their status when edited.

The admin ZIP does not include the Worker/backend source. The server must enforce `publish_at` and `expires_at`, suppress immediate Push for future-scheduled records, and dispatch them when due; the client alone cannot guarantee background scheduling while closed. Target-list preparation remains an explicit send action for already-published notifications.

## Security and source integrity

- The legacy `website/admin` source directory is removed from the migration package.
- The public website source and backend source remain present.
- Admin navigation is filtered by role for usability; API authorization remains the source of truth.
- The Eino monitor uses the backend's privacy-preserving telemetry contract and does not display prompts, responses, student IDs, IP addresses, or file contents.

## Verification limits

Focused widget tests cover content-section switching, immediate notification publishing without a type selector, and readable scheduled date/time rendering. This editing environment does not have Flutter/Dart installed, so those tests, `dart format`, `flutter analyze`, platform builds, and live API integration tests could not be executed here. The package must not be considered release-verified until those checks pass in CI and the changed flows are tested with authorized test accounts against the target API.

The source code's presence is not proof that production secrets, Cloudflare routes, D1 migrations, R2 media storage, or push delivery are configured. In particular, verify the deployed backend has migrations through `0038_content_notification_drafts.sql` and that `/admin/security/eino-monitor`, `/admin/moderation/feedback`, and `/admin/moderation/chat-reports` are deployed before relying on those screens in production.
