# TRINEX — R2 Media Storage

TRINEX uses the private Cloudflare R2 bucket `trinex-media` for editorial images and the site logo.
Google Drive remains the storage adapter for academic PDF materials.

## Safety limits

The application deliberately stops before the Cloudflare R2 free-tier ceiling:

- Standard storage tracked by TRINEX: **6 GiB maximum**.
- Uploads: **100,000 Class A operations/month maximum** from the application.
- One image: **3 MB maximum**.
- One media request: **1–5 images**.
- Allowed image formats: **JPEG, PNG, WebP**.
- R2 bucket must remain **private** (`Public Access: Disabled`).

R2 reads are served through the API Worker and cache headers are enabled. On the Workers Free plan, the Worker account has a hard 100,000-request/day ceiling, which also bounds application-driven R2 reads below R2's 10-million-Class-B monthly free allowance. Do not expose the bucket with `r2.dev` or upload unrelated objects manually if the goal is to keep this account strictly free.

## Required binding

`backend/wrangler.toml` contains:

```toml
[[r2_buckets]]
binding = "MEDIA_BUCKET"
bucket_name = "trinex-media"
```

Apply migrations before deploying the API:

```bash
npm run migrate:remote
npm run deploy
```

The API will fail closed for media uploads if the R2 binding is missing.
