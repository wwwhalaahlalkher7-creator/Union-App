# Refactor Status

## Current pass

This pass focuses on reducing UI-file responsibility without changing public routes or API contracts.

### Flutter
- `features/eino/eino_screen.dart`: extracted chat models and animation widgets into `eino_widgets.dart`.
- Eino-specific API error codes are now mapped by the shared `ErrorMessage` service.
- `features/settings/settings_screen.dart`: extracted presentation widgets into `settings_widgets.dart`.
- Settings screen remains responsible for state, user actions, navigation, and lifecycle only.

### Rules for subsequent passes
- Keep routes and API contracts stable unless a bug fix requires otherwise.
- Do not expose raw exceptions to users.
- Prefer shared error mapping over screen-specific error translations.
- Keep state/business logic separate from presentational widgets.
- Run all repository CI audit scripts after each refactor group.

## Validation

Passed repository checks:
- workflow consistency
- backend schema
- backend API contract
- backend API integrity
- auth hardening
- offline cache
- secure storage
- Eino dashboard/observability/provider/reliability
- admin CRUD/UI payload
- color theme
- web security
- XSS DOM checks

Flutter/Dart SDK was not installed in the execution environment, so `flutter analyze` and `flutter test` were not claimed as executed.

## Dependency injection pass
- Added `core/di/app_dependencies.dart` as the single application dependency container.
- A single authenticated `ApiClient`/`AuthStorage` pair is created during startup.
- Repositories are constructed once and reused by feature screens.
- Removed feature-level creation/disposal of `ApiClient` and `AuthenticatedClient` from auth, news, materials, learning events, XP, notifications, schedule, student, badges, settings, and Eino flows.
- `ContentRepository` now receives its client explicitly and no longer creates temporary authenticated clients.
- `StartupPreloader` reuses the application client.
- `UpdateService` now receives its client explicitly.
- The old `AuthenticatedClient` factory remains only as a deprecated compatibility API; no feature depends on it.
- Dependency container lifecycle safely resets after disposal.
