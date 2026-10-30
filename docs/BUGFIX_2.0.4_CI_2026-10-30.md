# TRINEX Platform 2.0.4 — CI bug fixes (2026-10-30)

## Student app analyzer fixes

- `AboutScreen` now constructs `UpdateService` with the initialized shared `ApiClient` from `AppDependencies`.
- `ContentListScreen` now reuses the shared `ContentRepository` instead of creating an invalid zero-argument repository and an unused network client.
- `ContentRepository` exposes the `announcements()` and `events()` methods and calls the existing public Worker routes.
- `SystemScreen` fallback snapshots now match the current `XpSnapshot` and `BadgeSnapshot` constructors. It also reuses the shared API client and does not dispose the application-wide client when the screen closes.
- Removed the accidentally duplicated `suspendWhileChatOpen` field from `_EinoOrbPainter`; the setting remains on `EinoFace`, where the lifecycle logic uses it.
- Added braces to the Eino early-return condition.

## D1 migration fix

The remote D1 database already has `students.is_moderator`, while Wrangler's migration ledger still reports `0035_student_moderators.sql` as pending. The previous `ALTER TABLE ... ADD COLUMN` therefore failed with `duplicate column name`.

The canonical fresh-install schema (`0001_initial.sql`) now defines `is_moderator`. Migration `0035_student_moderators.sql` only creates the moderator index with `IF NOT EXISTS`, making it safe for both:

- Fresh databases, where `0001` creates the column before `0035`.
- Existing databases where the column exists but `0035` is still pending.

## Validation performed

- Fresh SQLite migration chain: 39/39 migrations applied successfully.
- Existing-column simulation for migration 0035: passed.
- Fresh-install simulation for migration 0035: passed.
- `ci/final_release_check.py`: passed (`2.0.4+3`, 51 tables, applicationId `com.leoassociation.app`).
- `ci/release_check.py`: passed.
- `ci/version_consistency_check.py`: passed.
- `ci/backend_api_contract_check.py`: passed (58 required routes, 60 Flutter paths).
- `ci/backend_api_integrity_check.py`: passed.
- `ci/backend_schema_check.py`: passed (39 migrations, 51 tables, 191 indexes).
- `ci/backend_schema_audit.py`: passed (foreign keys OK).
- `ci/flutter_secure_storage_check.py`: passed.
- `ci/offline_cache_check.py`: passed.
- `ci/eino_orb_motion_check.py`: passed (8 checks).
- `ci/verify_project.py`: passed.
- `node --check` across Worker JavaScript files: passed.

## Not yet validated

Flutter SDK is not installed in the current execution environment. `flutter analyze`, `flutter test`, and Android APK build must still run in CI or a Flutter-enabled environment. No remote migration was applied and no production deployment was performed during this repair.


## Follow-up: D1 migration 0038 duplicate `materials.content_type`

The remote D1 database already contains `materials.content_type`, although Wrangler still reports `0038_exam_material_types.sql` as pending. The migration previously attempted to add the column again and failed.

Fix applied:
- Added `content_type TEXT NOT NULL DEFAULT 'material'` to the canonical `materials` table in `0001_initial.sql` for fresh databases.
- Changed `0038_exam_material_types.sql` to create only `idx_materials_type_subject_active`; it no longer alters the table.
- Kept migration numbering and release version `2.0.4+3` unchanged.

The failed remote attempt did not apply 0038, while the log confirms 0035, 0036, and 0037 succeeded. The next deployment should therefore resume at 0038 and then apply 0039. Do not reset D1 or manually delete migration history.
