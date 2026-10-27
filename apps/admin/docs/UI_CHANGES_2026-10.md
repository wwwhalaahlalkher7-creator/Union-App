# TRINEX Admin UI changes — 2026-10

## Implemented in this pass
- Student creation omits email and academic level; editing retains both and retains the active toggle.
- Staff creation omits the active toggle; editing retains it. Staff role labels are Arabic.
- Content-type selector is now a centered horizontal banner strip for news, achievements, and events. Announcements are removed from the content-type selector so they are handled through Notifications.
- Content image selection is placed at the end of the editor, uses the image picker, removes the editable image-URL field, and shows a network-image preview after upload.
- Content dates use a date picker and Arabic day/month/year display. The form derives draft/published status from the selected date and defaults missing dates to today. Future events show a “قريبًا” chip.
- Academic page now has two tabs: Materials and Schedules. Materials are represented as subject cards; selecting one opens its sheets, with per-sheet add/edit/delete actions. Drive sync is available at the top of the materials page.
- Schedule time fields use a time picker and display an explicit Arabic AM/PM label; values are serialized as HH:mm for the existing API.
- Dashboard stat and quick-action cards use two columns at medium/narrow mobile widths when space permits.
- Settings cards show Arabic-friendly labels alongside the technical key.
- Account page includes a pencil action and an edit dialog for display name and email.

## Backend follow-up required (intentionally not changed here)
- Automatic publication of future-dated content requires a backend scheduler or equivalent process; the UI sends a draft status for future news/achievements and published status for future events.
- The account editor expects `GET/PATCH /auth/staff/profile` to return/update `displayName` and `email`.
- The academic sheet form currently uses the existing material API fields (Drive file ID/URL). Selecting and uploading a local PDF requires a document-upload endpoint and its response contract; no backend route was guessed or added in this UI-only pass.
- Flutter/Dart SDK was not available in the execution environment, so `flutter analyze` and platform builds could not be run. A structural delimiter/string check passed for all Dart source files.
