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
- Website: Cloudflare Worker `leo-association-website` serving the public site and `/admin/` together

## Important

The public website under `website/` is the source of truth and uses the TRINEX API for public data.

The GitHub Actions website workflow deploys the complete website in one Cloudflare Worker: public pages at `/` and the administration dashboard at `/admin/`. The backend Worker remains deployed separately.

The final public domain/route must be attached to the `leo-association-website` Worker in Cloudflare; no domain or API credentials are stored in the repository.
