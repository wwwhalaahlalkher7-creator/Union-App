# TRINEX Architecture & Maintenance Guide

## Goal

The project follows a boundary-oriented architecture: UI handles presentation, repositories handle feature data access, the network layer handles transport, and the backend owns validation/business rules.

## Flutter layers

- `lib/app/` — application bootstrap and routing.
- `lib/core/` — cross-cutting infrastructure:
  - `errors/` — shared error model and user-facing error mapping.
  - `network/` — HTTP, authentication refresh, offline policy and response parsing.
  - `storage/` — secure/local persistence.
  - `theme/` — design tokens and theme.
  - `localization/` — translated UI strings.
- `lib/data/models/` — API/domain data models.
- `lib/data/repositories/` — feature data access and API boundaries.
- `lib/features/` — screens and feature-specific presentation.
- `lib/shared/` — reusable UI components and utilities.

### Error flow

`HTTP/API failure -> ApiException -> ErrorMessage.from(context, error) -> localized UI message`

Do not:
- display `Exception.toString()` directly to users;
- duplicate HTTP status handling inside screens;
- silently replace malformed API data with fake/empty domain objects unless that behavior is explicitly part of the contract;
- expose raw provider, database, stack-trace, or infrastructure errors.

## Backend layers

- `src/index.js` — routing and top-level request boundary.
- `src/core.js` — shared response, database, JSON and request utilities.
- `src/errors.js` — stable API error codes and default safe messages.
- feature modules (`auth.js`, `academic.js`, `admin.js`, `student.js`, etc.) — business rules and route handlers.
- `src/providers/` — external AI/provider adapters.

### Error contract

Every API failure should use the common envelope:

```json
{
  "success": false,
  "error": {
    "code": "STABLE_ERROR_CODE",
    "message": "Safe user-facing message",
    "details": null,
    "requestId": "..."
  }
}
```

`code` is the stable contract. `message` is safe for display. `requestId` is for support/debugging.

## Maintenance rules

1. Keep screens focused on UI state and interaction.
2. Put API calls in repositories/services rather than widgets.
3. Validate external data at the boundary.
4. Prefer named error codes over free-form error strings.
5. Keep localization in `app_localizations.dart`; do not hard-code user-facing text in infrastructure.
6. Keep authentication/session behavior inside the network/auth layer.
7. Do not introduce a new error-handling pattern when an existing shared helper can handle it.
8. When a feature grows beyond a few hundred lines, split reusable sections, controllers/state, and services instead of extending the screen indefinitely.

## Current refactor foundation

This refactor introduces:

- `core/errors/app_error.dart`
- `core/errors/error_message.dart`
- `core/network/response_parser.dart`
- `backend/src/errors.js`

These are intended as the foundation for the next incremental decomposition of the largest screens/modules. The existing feature behavior and API routes remain unchanged.
