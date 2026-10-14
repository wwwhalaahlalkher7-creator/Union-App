# Cache hardening — 2026-10-13

## Implemented in this patch

- Added in-flight GET coalescing in `ApiClient`; simultaneous identical GETs with the same account scope and cache policy share one Future/HTTP operation.
- Scoped in-memory GET cache keys by student identity for private responses as well as offline-cacheable responses.
- Added an explicit offline-cache allow-list. Student statistics, chat messages, progress, XP, Eino results, auth endpoints, and public student profiles are not persisted as offline JSON cache entries.
- Added a startup cleanup for sensitive entries that may have been persisted by older versions.
- Added a method to clear the current student's cache scope before logout.
- Removed the three-second preloader timeout wrapper. The app already launches the preloader with `unawaited`; identical screen requests now join its in-flight request instead of starting another request when the timeout expires.
- Added in-process cache counters for memory hits, persistent hits, network GETs, coalesced GETs, and offline fallback hits. Counters reset with the process and are available through `ApiClient.cacheMetrics` for diagnostics/tests.
- Added tests for concurrent GET coalescing, cache metrics, account-scope removal, and not persisting progress payloads.

## Deliberately not changed without a product decision

1. **List pagination:** public pages request up to 1,000 records and apply filtering/sorting in the browser. Replacing this with server pagination changes how old records are discovered and how client-side filters work. Decide whether lists should load 30–50 recent records first with a “load more” control, or continue loading all records.
2. **Eino source-file caching:** repeated questions may download the same Drive material more than once. A shared Worker/edge cache would reduce Drive downloads but would retain course-file bytes in Cloudflare's cache. Confirm whether course files may be cached centrally and choose a retention period before implementing it.
3. **Eino quota:** current global/day and per-student weighted-unit limits are product policy, not cache policy. The simulation suggests the global limit may be reached on exam peaks. Decide whether to raise the global limit, keep it and accept throttling, or add a queue/fair-share policy. Raising it can increase external provider spend.
4. **Offline personal learning data:** personal progress, XP, stats, and chat are no longer persisted by the generic offline JSON cache for privacy. If offline access to any of these is a required feature, specify exactly which data should be retained and for how long; it should use a purpose-built, account-scoped store and clear on logout.
5. **Cache capacity and TTLs:** no broad increase was made to the 80-entry limit or stale window. Their values should be tuned from measured hit/miss and payload-size data rather than guesses.

## Verification status

- Backend JavaScript syntax check: passed.
- Website packaging build: passed.
- `ci/offline_cache_check.py`: passed.
- `ci/verify_project.py`: passed.
- Flutter/Dart tests and formatting could not be run in this environment because Flutter/Dart SDKs are not installed. Run `dart format`, `flutter analyze`, and `flutter test` in the Flutter CI/release environment before shipping.
- No deployment was performed.
