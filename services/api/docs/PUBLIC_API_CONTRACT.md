# TRINEX Public API Contract

Base:

`https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## Public endpoints

### Health / version

- `GET /health`
- `GET /version`
- `GET /app/update?version=<installed>&build=<build>&platform=android`

### Public content

- `GET /public/news`
- `GET /public/events`
- `GET /public/activities` — compatibility alias to the current events catalogue.
- `GET /public/students/:id` — public-safe student profile; excludes student number, email and authentication fields.
- `GET /public/announcements`
- - `GET /public/news/:id`
- `GET /public/events/:id`
- `GET /public/achievements/:id`
- - `GET /public/achievements`
- `GET /public/settings`
- `GET /public/materials`
- `GET /market/items` — published engineering marketplace listings; supports optional `category`, `departmentId`, and `limit` query parameters.

Public content routes `/news`, `/events`, `/announcements`, `/achievements` are the canonical routes.

## Authentication endpoints

- `POST /auth/login`
- `POST /auth/staff/login`
- `POST /auth/staff/bootstrap`
- `GET /auth/staff/me`
- `POST /auth/staff/change-password`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/me`

## Student endpoints

- `GET /student/me`
- `GET /student/profile`
- `GET /student/stats`
- `GET /student/notifications`
- `DELETE /student/notifications/:id` — deletes only the authenticated student's own notification target and queued delivery.
- `POST /student/notifications/read`
- `POST /student/notifications/device`
- `DELETE /student/notifications/device`
- `GET /semesters`
- `GET /departments`
- `GET /subjects`
- `GET /materials`
- `GET /exams` — separate exam-file catalogue; exam materials are excluded from the ordinary materials list.
- `GET /materials/:id`
- `GET /schedule`
- `GET /progress`
- `GET /xp`
- `GET /badges`
- `POST /materials/:id/progress`

## Interaction endpoints

- `GET/POST /content/:type/:id/comments`
- `GET/POST /comments/:id/replies`
- `POST /content/:type/:id/reactions`
- `POST /comments/:id/reactions`
- `DELETE /comments/:id`
- `DELETE /replies/:id`
- `DELETE /content/:type/:id/reactions`
- `DELETE /comments/:id/reactions`

### General chat, feedback and analytics

- `GET/POST /chat/messages`
- `DELETE /chat/messages/:id` — own messages or student-moderator removals.
- `POST /chat/messages/:id/report`
- `POST /feedback` — authenticated student feedback with suggestion/bug/content/other categories.
- `POST /usage/events` — anonymous allowlisted screen metadata only.

## Eino

- `POST /eino/chat`
- `POST/GET /eino/chats`
- `GET/POST /eino/chats/:id/messages`
- `DELETE /eino/chats/:id`
- `POST /eino/long-summary`
- `POST /eino/file-analysis` (PDF and image files; other file types currently return 415).
- `POST /eino/image` (route is present but returns 503 until an image-generation provider is configured).

The Worker enforces input limits, quota governance and privacy-preserving telemetry before forwarding to Free.ai.

## Admin

Admin endpoints are under `/admin/*` and require staff authentication plus the relevant permission. They cover content CRUD, students, staff, schedule/material operations, moderation, notifications, audit/auth events, dashboard overview, Eino usage and Drive synchronization.

## Error contract

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Safe user-facing message",
    "details": null,
    "requestId": "uuid"
  }
}
```

Do not expose provider secrets, SQL errors, stack traces, raw tokens or private student data through this contract.

## Student registration and semester selection

`POST /auth/register`

Registration claims an existing student record created by the administration. The client cannot choose or overwrite the academic department or current semester during registration.

Request:
```json
{
  "studentNumber": "string",
  "email": "student@example.com",
  "password": "string",
  "confirmPassword": "string"
}
```

`email` is optional. The department and current semester returned after registration come from the existing `students` record.

`POST /student/semester` is retained only as a compatibility guard and returns `403 ACADEMIC_RECORD_READ_ONLY`. The official `students.current_semester_id` belongs to the academic record managed by administration.

Students can request another semester for read-only browsing by passing `semesterId` to the relevant GET endpoints (for example `/materials` or `/schedule`), without modifying their official student record. Materials intentionally permit historical-semester browsing; schedule remains restricted to active semesters.

## Eino media and memory endpoints

- `GET /eino/capabilities`
- `GET /eino/models`
- `GET /eino/memory?limit=30`
- `POST /eino/memory` with `{ "content": "...", "category": "general" }`
- `DELETE /eino/memory/:id`
- `POST /eino/vision` with JSON `{ "image": "data-url", "mode": "describe" }`
- `POST /eino/ocr` as multipart field `file` (maximum 10 MB)
- `POST /eino/stt` as multipart field `file` (maximum 25 MB), optional `language`
- `POST /eino/tts` with JSON `{ "text": "...", "voice": "af_heart" }`

The Flutter client allows longer network timeouts for these operations than ordinary API calls because the Worker/provider contracts allow up to 30 seconds for chat/vision/TTS and 60 seconds for OCR/STT.

## Interaction content types

The interaction API accepts only:

`news`, `event`, `announcement`, `achievement`.

The public detail API uses the plural route name `events`, while interaction routes use the singular content type `event`.

## Response envelopes

Successful responses always use:
```json
{"success":true,"data":{},"meta":{}}
```

`meta` is omitted when there is no metadata.

Client errors and server errors use the error envelope documented above. Database uniqueness conflicts are returned as `409 CONFLICT`; invalid foreign-key, NOT NULL, or CHECK data is returned as `400 DATA_CONSTRAINT` instead of being exposed as an unclassified `500`.


## Engineering marketplace

- `GET /market/items` is public and returns only rows with `active = 1` and `status = 'published'`. Draft or disabled offers are never exposed to students. An optional `departmentId` includes global listings plus listings scoped to that department.
- Dashboard CRUD is available through `GET/POST /admin/market-items` and `PATCH/DELETE /admin/market-items/:id`. Requests require an authenticated staff session and the normal content permissions.
- Arabic title and description are required. Image and contact URLs, when present, must use HTTPS. Publishing is an explicit status change; newly created records default to draft.
