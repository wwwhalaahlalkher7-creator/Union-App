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
## Eino + Leo OmniRoute

Eino now supports Leo OmniRoute as the primary OpenAI-compatible chat gateway.
Set `OMNIROUTE_BASE_URL` in `wrangler.toml` to either the full `/v1/chat/completions`
URL or the `/v1` base URL. `OMNIROUTE_API_KEY` must be configured as a Cloudflare secret when the OmniRoute gateway requires authentication. The Railway deployment template enables API-key protection by default, so store the gateway key as the Cloudflare secret `OMNIROUTE_API_KEY` (and in the deployment secret store used by CI if CI performs the deploy).

Routing is controlled by `EINO_PROVIDER`: `auto` prefers OmniRoute and falls
back to the existing Free.ai adapter for retryable upstream failures; `omniroute`
forces OmniRoute for chat; `free.ai` preserves the previous provider.

The `/api/v1/eino/capabilities` endpoint exposes the active provider/model and
capability metadata to the Flutter client without exposing credentials.

## Eino AI Core + long-term memory

Eino chat now routes through Leo OmniRoute first when `OMNIROUTE_BASE_URL` is configured, with Free.ai available as a retryable fallback. `GET /api/v1/eino/capabilities` exposes the current online capabilities without exposing provider credentials.

Long-term memory is student-owned and opt-in through `POST /api/v1/eino/memory`. D1 stores the canonical memory record and ownership metadata. When a self-hosted Chroma deployment is configured, the API also creates an embedding through OmniRoute and indexes the memory in Chroma. Chat retrieves relevant memories before constructing the model context. If Chroma is unavailable, Eino safely falls back to the latest D1 memories instead of failing the chat request.

Chroma configuration is optional and intentionally empty in the repository until a zero-cost/self-hosted instance is provisioned:
- `CHROMA_BASE_URL`
- `CHROMA_TENANT`
- `CHROMA_DATABASE`
- `CHROMA_COLLECTION_ID`
- secret `CHROMA_TOKEN` when authentication is enabled

The Flutter repository exposes `capabilities()`, `memories()`, `remember()`, and `forgetMemory()` so the Eino UI can surface these controls in a later UI phase.
