# TRINEX API

Cloudflare Worker + D1 API الموحد للتطبيق والموقع ولوحة الإدارة.

## Quick start

```bash
npm install --no-audit --no-fund
node --check src/index.js
npm run migrate:local
npm run dev
```

## Production

- Worker config: `wrangler.toml`
- Entry point: `src/index.js`
- Database: D1 `leo-association-db`
- Migrations: `migrations/`
- Drive adapter: `apps-script/`

## Important

Google Apps Script ليس API عامًا للتطبيق؛ دوره الحالي هو قراءة وفهرسة Google Drive عبر adapter محمي بـtoken. التطبيق والموقع واللوحة يتعاملون مع TRINEX API فقط.

الأسرار لا تُحفظ في Git. راجع `../docs/CONFIGURATION.md`.

API contract: `docs/PUBLIC_API_CONTRACT.md`.
