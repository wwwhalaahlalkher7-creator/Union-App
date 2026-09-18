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
