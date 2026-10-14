# Maintenance Audit — 2026-09-29

## Scope

- Removed generated website `dist/` from the source package.
- Removed unused Flutter screens/widgets and obsolete UX stage documentation.
- Removed the duplicate backend database-schema document; `docs/DATABASE_SCHEMA.md` remains canonical.
- Corrected website documentation to the current `website/admin/` layout and `ci.yml` deployment path.
- Split the Cloudflare Worker implementation into domain modules while keeping `backend/src/index.js` as the HTTP router/entry point.
- Updated CI checks to inspect the modular backend instead of assuming implementation lives in `index.js`.

## Backend modules

- `core.js` — response helpers, JSON parsing, D1 helpers, crypto/shared limits.
- `auth.js` — student/staff authentication and sessions.
- `public.js` — public API.
- `student.js` — student profile/notifications/devices.
- `academic.js` — academic data, materials, schedule, progress, XP, badges.
- `interactions.js` — comments/replies/reactions.
- `media.js` — R2 media.
- `admin.js` — permissions, CRUD, moderation, audit.
- `eino.js` — Eino gateway, memory, media, quota, telemetry.
- `drive.js` — Google Drive adapter.

## Integration verification

- Backend syntax check: PASS.
- ESM module loading: PASS.
- Worker smoke requests for health, Eino capabilities, and unknown-route handling: PASS.
- API contract audit: PASS — 38 required routes, 39 Flutter paths.
- API integrity audit: PASS.
- D1 schema validation/audit: PASS — 28 migrations, 40 tables, 154 indexes.
- Admin CRUD audit: PASS.
- Auth hardening audit: PASS.
- Eino provider and routing matrix audits: PASS.
- Eino observability audit: PASS.
- Release/final-release checks: PASS.
- Web security and XSS checks: PASS.
- Website build: PASS.
- Flutter import graph: 73/73 Dart files reachable from `main.dart`.

## Important limitation

The current inspection environment does not contain the Flutter SDK, so `flutter analyze`, `flutter test`, and a real Android APK/AAB build were not executed here. The repository's Flutter/Android CI remains the authoritative environment for those checks.
