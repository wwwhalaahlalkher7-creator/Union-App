# TRINEX Admin — Content and Notifications Follow-up

Date: 2026-10-18

## Content navigation

- Content sections use standard Material buttons and reload the selected section.
- Request revision tracking prevents a late response from a previous section overwriting the current list.

## Notifications UI

- Removed the large delivery-information card and the top-level audience/read-count tiles.
- Removed the draft counter and generic draft filter. The only visible drafts are generated reviews linked to academic schedule/material updates.
- New manual notifications always save with `status: published`. Future `publish_at` values are displayed as scheduled; the client never stores a `scheduled` status that the API schema does not accept.
- Schedule/material notification drafts retain their draft state until approved. Approval publishes them and queues immediate delivery, or leaves future-dated entries to the server scheduler.
- The notification editor no longer exposes a type selector. For manual announcements, type is `academic` when a department or semester is targeted and `general` otherwise; existing schedule/material notification types are preserved.
- Publish and expiry times support both date and time. Selected local time is serialized as UTC ISO-8601, converted back to local time for display, and rendered left-to-right to avoid RTL date reversal.
- Expired notifications are labelled as expired and their manual send action is disabled.
- Search, audience targeting, editing and delete confirmation remain available.

## Matching backend behavior

The paired `Union-App` archive contains the backend changes and migration `0045_notification_auto_publish.sql`. Manual announcements are created as published, future dates are enforced in the scheduler and student API, timestamps are normalized to UTC, and only schedule/material-generated notification records remain drafts. The Durable Object scheduler recalculates its next alarm after relevant admin writes.

## Verification

- Widget tests cover content-section switching, immediate publishing without a type selector, removal of marked summary elements, readable date/time rendering, and academic-draft approval.
- Backend `npm run check`, migration/schema audits, API contract checks and the notification scheduling regression check passed in the editing environment.
- Flutter/Dart SDK is unavailable in the editing environment, so `dart format`, `flutter analyze`, `flutter test`, native builds and live Cloudflare/D1/FCM tests were not run locally. Run project CI before production release.
