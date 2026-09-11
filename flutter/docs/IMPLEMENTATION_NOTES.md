# Implementation Notes

## What was changed from the initial release

1. Removed the old five-item navigation concept from the active router.
2. Added Home / Schedule / Materials / More as the active primary navigation.
3. Moved News, Announcements, Activities, Achievements, Favorites, Recent,
   Notifications, Settings and About into the More area.
4. Kept student access as a non-blocking informational screen only.
5. Added persistent language selection and Arabic/English/French localization.
6. Added POST support to the API client without wiring student authentication
   into startup.
7. Added repository/model foundations for content and materials.
8. Replaced fake news placeholders with real API-backed empty/error states.
9. Kept unavailable backend functionality explicit instead of inventing data.
10. Updated release documentation to distinguish the agreed API contract from
    routes that are not yet deployed.

## Deliberately not implemented

- Student registration/authentication.
- Student access tokens/refresh handling in the UI.
- Commercial ads.
- Fake content.
- Hardcoded subject lists.
- REST backend migration itself.

Those are backend/product decisions, not UI placeholders to silently invent.
