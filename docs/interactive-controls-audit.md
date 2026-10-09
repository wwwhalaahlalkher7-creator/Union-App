# TRINEX / Union-App — Interactive Controls Audit

## Scope checked

- Website and admin UI: all 19 HTML pages under `website/`.
- Static inventory: 39 button-like controls, 74 anchors, and 4 forms.
- Navigation checks: local links, script references, and placeholder links.
- Control wiring checks: static references to IDs used by interactive controls.
- Flutter source: scanned for explicit `onPressed: null`, `onTap: null`, and button-related TODO/FIXME markers; none were found by these simple patterns. The source contains 87 `onPressed:` declarations and 37 `onTap:` declarations (declarations, not a count of unique visible controls).
- Existing Flutter test suite: 8 test files present.

## Changes made

- PDF modal actions “Open in Drive” and “Download” no longer start as active `href="#"` links.
- Those actions become enabled only after a valid HTTPS URL is assigned when a file is opened.
- Closing the modal removes the old URLs and disables the actions again, preventing accidental navigation or stale-link reuse.
- Added `ci/interactive_controls_audit.py`, a dependency-free static audit for missing local targets, script references, and controls without a detectable handler reference. Added it to the website CI checks.

## Automated checks run

- `npm run build` — PASS.
- `python3 ci/web_security_check.py` — PASS.
- `python3 ci/website_audit_regression_check.py` — PASS.
- `python3 ci/interactive_controls_audit.py` — PASS (19 pages, 39 buttons, 74 links, 4 forms).
- `python3 ci/xss_dom_check.py` — PASS.
- `python3 ci/admin_ui_payload_check.py` — PASS.
- `node ci/api_authorization_check.mjs` — PASS (25 route-permission cases, 4 role scopes).
- `npm --prefix backend run check` — PASS (backend JavaScript syntax).
- Website JavaScript syntax checks — PASS.

## Important limitations

This is not a claim that every button has been proven functional in a live session. The local browser run was blocked by the environment's Chromium policy (`ERR_BLOCKED_BY_ADMINISTRATOR`) for local HTTP pages, and Flutter tooling is not installed in this environment. Therefore these tasks remain unverified here: real browser click-through for every website/admin control; authenticated CRUD against a running API and database; device-level Flutter taps/navigation; external OAuth/Drive/email/notification integrations; and permission tests with real accounts. The CI checks added here are regression/static checks, not a substitute for those runtime tests.
