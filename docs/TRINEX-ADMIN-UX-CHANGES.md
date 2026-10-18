# TRINEX Admin UX integration changes — 2026-10-14

This patch is shared across the standalone Flutter administration app and Union-App's backend/student app/website source.

## Included
- Arabic labels for admin roles while preserving stable role IDs.
- Student admin form omits email and current academic level so the student can provide them in the student app; omitted fields are not cleared on edit.
- Content editor uses calendar date pickers for publication/event/achievement dates and image selection with preview. Android/mobile uses the gallery; desktop uses the platform file picker.
- Future news and achievements are saved as drafts and the Cloudflare scheduled handler promotes dated drafts when their date arrives. Content with no date or a past date is published immediately.
- Future events are exposed to clients as upcoming; student media cards display “قريباً”.
- Standalone media upload entry removed from admin navigation.
- Staff self-profile PATCH endpoint updates display name and email with validation and duplicate-email protection.

## Validation performed
- `node --check` passed for backend `auth.js`, `index.js`, and `public.js`.
- `ci/admin_crud_check.py` passed.
- `ci/admin_ui_payload_check.py` passed.
- `ci/website_audit_regression_check.py` passed.
- Flutter analyzer/build not run because Flutter SDK is unavailable in this execution environment. Run Android APK and Windows builds in CI before release.

## Remaining manual/CI verification
- Test Android gallery and Windows image selection.
- Test scheduled publication with a dated draft on the deployed Cloudflare Worker.
- Confirm API profile update with an authenticated staff account.
- Full combined courses/materials/Drive page and dedicated results-management page require further implementation after confirming the existing backend data contract for results.
