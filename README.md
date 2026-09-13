# TRINEX

Monorepo structure for the TRINEX ecosystem.

```text
TRINEX/
├── app/                 # Flutter mobile application
├── website/             # Public website source
│   └── dashboard/       # TRINEX administration dashboard
├── backend/             # Cloudflare Worker + D1 API
└── .github/workflows/   # Automated deployment workflows
```

## Production endpoints

- Public website: https://ush-eng.great-site.net
- API: https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1
- Dashboard: Cloudflare Worker `leo-association-dashboard` (workers.dev until a controlled custom domain/route is configured)

## Important

The current public website still uses its existing HTML/CSS/JS + Apps Script stack. Its migration to the TRINEX API is intentionally deferred until the current website files are available.

When the website files are added under `website/`, they become the source of truth for the public site. The dashboard remains isolated under `website/dashboard/`.

The dashboard workflow deploys only `website/dashboard/**`; public website files do not get copied into the dashboard deployment.
