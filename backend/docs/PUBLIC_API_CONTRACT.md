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
- `GET /public/announcements`
- `GET /public/activities`
- `GET /public/news/:id`
- `GET /public/events/:id`
- `GET /public/activities/:id`
- `GET /public/achievements`
- `GET /public/settings`
- `GET /public/materials`

Legacy-compatible public content routes `/news`, `/events`, `/announcements`, `/activities`, `/achievements` remain implemented for compatibility.

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

## Interaction endpoints

- `GET/POST /content/:type/:id/comments`
- `GET/POST /comments/:id/replies`
- `POST /content/:type/:id/reactions`
- `POST /comments/:id/reactions`
- `DELETE /comments/:id`

## Eino

- `POST /eino/chat`

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

Request:
```json
{
  "studentNumber": "string",
  "departmentId": "string",
  "semesterId": "string",
  "email": "student@example.com",
  "password": "string",
  "confirmPassword": "string"
}
```

`POST /student/semester`

Request:
```json
{"semesterId":"string"}
```

Materials intentionally permit a registered student to request historical semesters. This is different from the schedule endpoint, which only exposes active semesters.

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

`news`, `event`, `activity`, `announcement`, `achievement`.

The public detail API uses plural route names (`events`, `activities`) while interaction routes use the singular content type (`event`, `activity`).

## Response envelopes

Successful responses always use:
```json
{"success":true,"data":{},"meta":{}}
```

`meta` is omitted when there is no metadata.

Client errors and server errors use the error envelope documented above. Database uniqueness conflicts are returned as `409 CONFLICT`; invalid foreign-key, NOT NULL, or CHECK data is returned as `400 DATA_CONSTRAINT` instead of being exposed as an unclassified `500`.
