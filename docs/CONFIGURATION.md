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
| `EINO_*_DAILY_LIMIT` | Variable | حدود Eino اليومية |
| `GOOGLE_APPS_SCRIPT_URL` | Variable | رابط Drive adapter |
| `ALLOWED_ORIGINS` | Variable | Origins المسموح بها للمتصفح |

الأسرار:

| Secret | الاستخدام |
|---|---|
| `FREE_AI_BASE_URL` | عنوان Free.ai API الاحتياطي |
| `FREE_AI_API_KEY` | مفتاح Free.ai الاحتياطي |
| `MISTRAL_API_KEY` | مفتاح Mistral |
| `GROQ_API_KEY` | مفتاح Groq |
| `EINO_MISTRAL_TEXT_MODEL` | نموذج النص الأساسي: `mistral-small-2603` |
| `EINO_GROQ_TEXT_MODEL` | نموذج النص الاحتياطي: `openai/gpt-oss-120b` |
| `EINO_MISTRAL_VISION_MODEL` | نموذج الرؤية: `mistral-small-2603` |
| `EINO_GROQ_VISION_MODEL` | نموذج الرؤية الاحتياطي: `qwen/qwen3.8-27b` |
| `EINO_MISTRAL_OCR_MODEL` | OCR الأساسي: `mistral-ocr-latest` |
| `EINO_GROQ_STT_MODEL` | STT الأساسي: `whisper-large-v3-turbo` |
| `EINO_GROQ_TTS_MODEL` | TTS العربي الأساسي: `canopylabs/orpheus-arabic-saudi` |
| `EINO_EMBEDDING_BASE_URL` | مزود embeddings الاختياري بصيغة OpenAI-compatible |
| `EINO_EMBEDDING_MODEL` | نموذج embeddings الاختياري |
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
- Eino providers: `MISTRAL_API_KEY`, `GROQ_API_KEY`, و`FREE_AI_API_KEY` عند تفعيل fallback الأخير.
- Eino embeddings: `EINO_EMBEDDING_BASE_URL`, `EINO_EMBEDDING_API_KEY`, `EINO_EMBEDDING_MODEL` عند تفعيل الذاكرة الدلالية.
- Android signing: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`.
- InfinityFree: `INFINITYFREE_FTP_USERNAME`, `INFINITYFREE_FTP_PASSWORD`.

- InfinityFree remote deployment path: `/ush-eng.great-site.net/htdocs/`.

## قبل تغيير secret

1. تأكد من اسم المتغير في `backend/wrangler.toml` وworkflow.
2. لا ترسل القيمة في issue أو chat أو commit.
3. إذا تغير اسم secret، حدّث كل المستهلكين في نفس التغيير.
4. بعد التغيير شغّل workflow أو فحص health المناسب.
