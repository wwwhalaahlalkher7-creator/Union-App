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
- `GET /public/activities`
- `GET /public/announcements`
- `GET /public/news/:id`
- `GET /public/activities/:id`
- `GET /public/achievements/:id`
- `GET /public/achievements`
- `GET /public/settings`
- `GET /public/materials`

Public content routes `/news`, `/activities`, `/announcements`, `/achievements` are the canonical routes. The activities route is backed by the existing content table for deployment compatibility.

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
- `GET /public/students/:id` (public profile; exposes name, department, and semester only)
- `GET /student/stats`
- `GET /student/notifications`
- `POST /student/notifications/read`
- `POST /student/notifications/device`
- `DELETE /student/notifications/device`
- `GET /semesters`
- `GET /departments`
- `GET /subjects`
- `GET /materials`
- `GET /materials/:id`
- `GET /schedule`
- `GET /progress`
- `GET /xp`
- `GET /badges`
- `POST /materials/:id/progress`

## General student chat

The public chat feature is implemented in the Flutter app and moderated through the existing staff moderation page in the website admin panel.

- `GET /chat/messages?limit=50` — authenticated students only; returns the latest visible messages and public author fields.
- `POST /chat/messages` — authenticated students only; creates a plain-text message (maximum 1,000 characters, throttled to five messages per 15 seconds).
- `DELETE /chat/messages/:id` — soft-deletes the authenticated student's own message.
- `POST /chat/messages/:id/report` — reports another student's message for moderation. One report per reporter/message.
- `GET /admin/moderation/chat-reports?status=open` — staff with `moderation.read` permission.
- `PATCH /admin/moderation/chat-reports/:id` — staff with `moderation.write` permission; resolves a report and may change the message status to visible, hidden, or deleted.

The Flutter client refreshes messages periodically (polling); this release does not claim WebSocket/push-based realtime delivery. Only active student sessions can read or write chat messages. Email, university number, and authentication data are never returned in chat message payloads.

## Interaction endpoints

- `GET/POST /content/:type/:id/comments`
- `GET/POST /comments/:id/replies`
- `POST/DELETE /content/:type/:id/reactions`
- `POST/DELETE /comments/:id/reactions`
- `DELETE /comments/:id`

## Eino

- `POST /eino/chat`
- `POST /eino/chats`
- `GET /eino/chats`
- `GET /eino/chats/:id/messages`
- `POST /eino/chats/:id/messages`
- `DELETE /eino/chats/:id`
- `POST /eino/vision`
- `POST /eino/ocr`
- `POST /eino/stt`
- `POST /eino/tts`

Student chat history is stored per student in D1 and can be resumed across app sessions. Long-term Eino memory is available only to authenticated students. Media uses dedicated Eino vision/OCR/STT endpoints; TTS normalizes either provider audio URLs or base64 audio into a client-consumable response.

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

`news`, `activity`, `announcement`, `achievement`.

The public detail API uses the plural route name `activities`, while interaction routes use the canonical content type `activity`.

## Response envelopes

Successful responses always use:
```json
{"success":true,"data":{},"meta":{}}
```

`meta` is omitted when there is no metadata.

Client errors and server errors use the error envelope documented above. Database uniqueness conflicts are returned as `409 CONFLICT`; invalid foreign-key, NOT NULL, or CHECK data is returned as `400 DATA_CONSTRAINT` instead of being exposed as an unclassified `500`.
