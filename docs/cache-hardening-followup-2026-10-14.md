# Union-App cache hardening follow-up — 2026-10-14

## Decisions implemented

1. Personal offline learning state and conversations (student profile/stats, progress, XP, badges, schedule, general chat, Eino conversations/messages/memory) are eligible for offline fallback only under a `student:<studentNumber>` cache scope. The private payload cache is stored through `flutter_secure_storage`, not the public SharedPreferences JSON cache. Logout removes the student's in-memory and secure-storage cache entries before clearing auth state. Legacy account-scoped sensitive entries found in the older SharedPreferences cache are migrated to secure storage at startup; legacy unscoped sensitive entries are purged.
2. Public news, activities, achievements, and the public materials catalogue are requested in pages of 50 with `offset` support and “load more” controls. Flutter media lists and the website pages retain client-side filtering/sorting over records already loaded. The course catalogue retains global search across loaded pages and adds newly loaded departments/semesters to the index.
3. Eino material retrieval now uses best-effort Cloudflare Cache API caching for six hours. The cache key includes the Drive file ID and the latest available version marker (`drive_modified_at`, falling back to `updated_at` or `created_at`). Authorization and student department/semester filtering still happen before the file is retrieved from cache or Drive. Cache errors do not block a normal Drive fetch.
4. Eino's global weighted-unit daily limit is now 2,000 by default and in `backend/wrangler.toml`; per-student (50), guest (10), and burst limits are unchanged. Deployment environments that override `EINO_GLOBAL_DAILY_LIMIT` must be checked separately.
5. Website public-list and course-index caches now return stale cached data immediately, refresh storage in the background, and display the refreshed data on a later visit. Cache key versions were advanced where pagination changed the shape/semantics of the stored list.

## Verification performed

- Backend JavaScript syntax checks: passed (`npm run check`).
- Website build/packaging: passed (`npm run build`).
- Website inline JavaScript syntax checks for news, activities, achievements, and courses: passed.
- All Python CI scripts: passed on 2026-10-14.
- All JavaScript `.mjs` CI checks: passed on 2026-10-14.
- Additional `ci/cache_hardening_check.mjs`: passed.
- Flutter/Dart formatting, analyzer, unit tests, and APK build were not run because Flutter/Dart SDKs are not installed in this environment. The offline cache tests were extended to cover secure account-scoped storage, but require execution in Flutter CI.
- Cloudflare Cache API behavior, real Drive file cache hits, real D1 row metrics, and actual Eino quota enforcement were not exercised against production. No deployment or live service request was performed.

## Notes and boundaries

- Eino file caching is best-effort and local to Cloudflare's Cache API data-center cache; cache hit rates can vary by location. The six-hour retention policy is expressed in response headers and uses a versioned cache key.
- Eino's quota increase changes the code and repository Wrangler variable only. Any separately configured dashboard/environment variable with value `1000` takes precedence and must be updated manually by the operator when they choose to deploy.
- Account-scoped cache eviction remains capped at 160 entries per student. Expired offline data is limited by the existing seven-day stale fallback policy.
- Nothing was deployed. The output is a source package for review and testing.
