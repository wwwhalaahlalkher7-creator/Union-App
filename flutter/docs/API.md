# API Integration — v1.2

The Flutter app now consumes the deployed Association API on Cloudflare Workers.

Base URL:

`https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## Public actions

- `?action=health` — gateway health.
- `?action=news` — news from the content service.
- `?action=announcements` — announcements.
- `?action=activities` — activities.
- `?action=achievements` — achievements.
- `?action=materials&nocache=1` — Google Drive materials index.
- `?action=schedule` — public schedule metadata and entries.

The schedule is backed by a Google Sheet created automatically by Unified API v1.2 on first request. It starts empty; no fake classes are inserted.

Student authentication remains optional and is not required to start or use the app.
