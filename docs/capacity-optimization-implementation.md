# Union-App capacity optimization — implementation notes

## Implemented in this source package

### Flutter app
- Public news, activities, and achievements load 50 records per page with offset-based pagination and a load-more control. The startup preloader warms the same `limit=50&offset=0` cache variants used by the content repository.
- Explicitly cacheable GET requests return fresh cached data first. Account-scoped student learning data and general/Eino conversation history are stored in OS secure storage, can be used for offline fallback for up to seven days, and are removed on logout. Public catalogue data remains in the ordinary public cache.
- Materials, subjects, and semesters use a 7-day cache; timetable uses 24 hours; student profile uses 15 minutes; student stats use 10 minutes; progress uses 5 minutes; badges use 24 hours; XP uses 10 minutes.
- Confirmed XP awards invalidate the local XP/stat cache; progress events invalidate cached badges and progress. Content reactions invalidate the matching public content cache.
- PDF files are kept in app support storage instead of temporary storage. Page changes save the latest progress locally; progress is synchronized every 60 seconds and on app lifecycle transitions. Failed progress requests remain in a per-student local queue.
- Content/comment reactions save the desired final state when a retryable network error occurs. The queue is retried on later content/comment navigation; POST upserts and DELETE are safe to repeat.
- Public chat polling changed from 5 seconds to 10 seconds, stops while the app is backgrounded, and refreshes on resume. A short local cache avoids repeated immediate requests.

### Worker/backend
- The XP and student-stats GET handlers no longer write to D1 just because a screen was opened. They use `student_stats` when present and fall back to a read-only aggregate for legacy records.
- Badge evaluation after PDF progress runs only when the recorded page/percentage/completion meaningfully changes, rather than on every time-only heartbeat.
- Added `GET /api/v1/public/counters` for lightweight homepage counts. It avoids loading 50 full news/activity records and their per-record counts just to animate two counters.
- The counters endpoint advertises short public cache headers. Media cache fallback lifetime is one week with stale-while-revalidate.

### Public website
- Site settings are cached locally for 10 minutes and stale values remain visible during temporary API outages.
- News and activities lists are paged at 50 records and cached locally for 12 hours; achievements are paged at 50 and cached for 24 hours. When stale cached data exists, pages render immediately while the cache refreshes in the background for the next visit.
- The homepage uses the lightweight counters endpoint and a 15-minute local cache.
- The course catalogue local cache lasts 7 days (manual refresh remains available). Its public API index now loads 50 materials at a time, with a load-more control that extends the global search index.
- GitHub latest-release metadata is cached for one hour, with stale cached metadata used during temporary API outages.

## Validation performed
- `npm run build` for the website packaging succeeded.
- `npm run check` in `backend/` succeeded (Node syntax checks for backend source files).
- All Python checks in `ci/` passed.
- All `ci/*.mjs` checks passed.
- Inline JavaScript syntax checks passed for the modified public pages and settings script.

## Validation limitation and remaining work
- Flutter SDK/Dart tooling was not available in the execution environment, so `flutter analyze`, Flutter unit tests, and an APK build could not be run here. The Flutter changes still need validation in the project's GitHub Actions Flutter environment before release.
- This package does not deploy anything; backend and website changes are source-only until separately deployed.
- The dedicated “Download to device/Downloads” control for PDFs, optimistic pending chat bubbles/message idempotency, and a generalized network-return sync coordinator for every offline write are not included in this pass. The course catalogue's load-more control appears with the section tabs; only records already loaded into the index are included in global search.
