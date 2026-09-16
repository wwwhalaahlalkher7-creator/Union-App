# Configuration & Secrets

## قاعدة ذهبية

**المستودع لا يحتوي أسرار إنتاج.** أي قيمة حساسة يجب أن تكون في GitHub Secrets أو Cloudflare Secrets أو Script Properties الخاصة بـGoogle Apps Script.

## Cloudflare Worker

المتغيرات العامة الحالية في `backend/wrangler.toml`:

| المتغير | النوع | الغرض |
|---|---|---|
| `APP_VERSION` | Variable | آخر إصدار يعلنه API |
| `MINIMUM_APP_VERSION` | Variable | أقل إصدار مدعوم |
| `APP_UPDATE_URL` | Variable | صفحة التحديث إن وجدت |
| `APP_RELEASE_NOTES` | Variable | ملاحظات الإصدار |
| `API_VERSION` | Variable | عقد API، حاليًا `v1` |
| `EINO_MODEL` | Variable | نموذج Eino، الافتراضي `qwen3-8b` |
| `EINO_*_DAILY_LIMIT` | Variable | حدود Eino اليومية |
| `GOOGLE_APPS_SCRIPT_URL` | Variable | رابط Drive adapter |
| `ALLOWED_ORIGINS` | Variable | Origins المسموح بها للمتصفح |

الأسرار:

| Secret | الاستخدام |
|---|---|
| `FREE_AI_BASE_URL` | عنوان Free.ai API، عادة `https://api.free.ai/v1` |
| `FREE_AI_API_KEY` | مفتاح Free.ai (`sk-free-...`) |
| `GOOGLE_APPS_SCRIPT_TOKEN` | مصادقة Worker مع Drive adapter |
| `STAFF_BOOTSTRAP_TOKEN` | تهيئة أول مدير عند الحاجة |

لا تضع هذه القيم في Dart أو JavaScript الخاص بالواجهة.

## Google Apps Script

`backend/App Script/Code.gs` يحتاج Script Properties:

- `ROOT_FOLDER_ID`
- `API_TOKEN`

تفاصيل النشر موجودة في `backend/App Script/README_AR.md`.

## GitHub Actions

الأسرار المستخدمة حاليًا تشمل، بحسب workflow:

- Cloudflare: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
- Eino/Free.ai: `FREE_AI_BASE_URL`, `FREE_AI_API_KEY`.
- Android signing: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`.
- InfinityFree: `INFINITYFREE_FTP_USERNAME`, `INFINITYFREE_FTP_PASSWORD`, `INFINITYFREE_FTP_REMOTE_DIR`.

## قبل تغيير secret

1. تأكد من اسم المتغير في `backend/wrangler.toml` وworkflow.
2. لا ترسل القيمة في issue أو chat أو commit.
3. إذا تغير اسم secret، حدّث كل المستهلكين في نفس التغيير.
4. بعد التغيير شغّل workflow أو فحص health المناسب.
