# TRINEX Monorepo migration note

## What changed

- Started a fresh Git repository history; previous `.git` objects and metadata were intentionally excluded.
- Moved the student Flutter application to `apps/student/`.
- Moved the native administration Flutter application to `apps/admin/`.
- Moved the Cloudflare Worker and D1 migrations to `services/api/`.
- Moved the public website and its static Worker to `web/portal/`; the supplied archive did not include a `website/admin/` tree, and the Worker already returns 404 for `/admin/`. The native admin UI lives in `apps/admin/`.
- Kept cross-project integrity/security checks at root `ci/` so their root detection remains stable.
- Centralized Actions workflows in root `.github/workflows/`.
- Updated repository-relative paths in checks and documentation; replaced stale web-dashboard-only static checks with checks for the native admin app and the existing API/Apps Script boundaries.
- Aligned the native Eino monitor screen with the implemented `/admin/security/eino-usage` endpoint and its `summary`/`buckets` response structure.
- Added path-based deployment guards so a commit that only changes the admin Flutter app does not deploy the API or website.

## Version decisions

| Component | User-facing version | Flutter version string | Canonical source |
|---|---|---|---|
| Student app | `v2.0.3` | `2.0.3+2` | `apps/student/VERSION` |
| Admin app | `v1.1.0` | `1.1.0+1` | `apps/admin/pubspec.yaml` |
| Backend API | `v1` | Not applicable | `services/api/wrangler.toml` |

The admin request `v1.1` is represented as `1.1.0` to comply with the semantic version format expected for a Flutter package. The build number is kept separately as `+1`.

## Before connecting this to a remote

1. Create/choose the intended GitHub repository and push the new initial commit.
2. Reconfigure GitHub Secrets / Variables for Android signing, Cloudflare deployment, and website FTP deployment. Secrets are not included in this export.
3. Verify that the new repository's main branch is `main` and configure environments/branch protection.
4. Run CI without production deployment first, then explicitly verify each deployment path.
5. Confirm the Cloudflare D1 binding and production migrations. Moving files does not move or recreate the remote database.

## Verification limitations

This migration is a source-tree refactor only. It does not publish a release, deploy a Worker or website, modify production D1, or prove signed builds; those operations require the target GitHub repository's secrets and runners.
