# Flutter cache CI failure follow-up — 2026-10-14

## Reported CI failures

The GitHub Actions run reported one Dart analyzer info and two failures in `flutter/test/api_client_cache_test.dart`:

- `coalesces concurrent identical GET requests into one HTTP call`
- `does not persist personal progress payloads to the offline cache`

## Changes made

1. Wrapped the single-line `if` statements in `api_client.dart` with blocks to clear the analyzer info about `curly_braces_in_flow_control_structures`.
2. Added `ApiClient.resetCachesForTesting()` to clear in-memory response/in-flight maps and reset cache metrics between tests. This prevents static process state from making the concurrent-request test order-dependent.
3. Added an in-memory `PersonalCacheStore` fake to `api_client_cache_test.dart`. The tests no longer rely on a platform `FlutterSecureStorage` plugin being registered in the unit-test environment.
4. Reworked the concurrent-request test to wait until the first mock HTTP request has actually entered the transport before starting the second identical request, rather than relying on a fixed 20 ms delay.
5. Strengthened the personal-progress test to check the public persistent cache payload and fake secure store as well as the public cache key.

## Validation status

- All repository Python CI checks passed in the available environment.
- All repository JavaScript `.mjs` CI checks passed in the available environment.
- `ci/offline_cache_check.py`, `ci/cache_hardening_check.mjs`, `ci/eino_quota_policy_check.mjs`, and `ci/verify_project.py` passed.
- Flutter/Dart could not be executed in this environment because the SDK is not installed. The two named Flutter tests have been corrected for deterministic setup, but their passing status must be confirmed by rerunning `flutter analyze` and `flutter test` in GitHub Actions.
- No website/backend deployment or production database changes were performed.
