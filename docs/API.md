# API — دليل الصيانة

## Base URL

الإنتاج:

`https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

الإصدار الحالي: `v1`.

العقد التفصيلي للمسارات العامة موجود في `backend/docs/PUBLIC_API_CONTRACT.md`.

## المجموعات

| المجموعة | أمثلة | المصادقة |
|---|---|---|
| Health / version | `/health`, `/version`, `/app/update` | عامة |
| Public content | `/public/news`, `/public/events`, `/public/announcements`, `/public/achievements`, `/public/materials` | عامة |
| Auth | `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/staff/login` | حسب المسار |
| Student | `/student/me`, `/student/stats`, `/student/notifications` | Student session |
| Academic | `/semesters`, `/departments`, `/subjects`, `/materials`, `/schedule` | بعض المسارات محمية |
| Progress | `/progress`, `/xp`, `/badges`, `/materials/:id/progress` | Student session |
| Student feedback | `POST /feedback` | Student session |
| Feedback moderation | `/admin/moderation/feedback` | Staff session + `moderation.read/write` |
| Interactions | comments/replies/reactions | Student session |
| Eino | `/eino/chat` | سياسة Eino + session/guest rules |
| Admin | `/admin/*` | Staff session + permission |

## Response shape

الاستجابات الناجحة تستخدم envelope موحدًا من نمط:

```json
{
  "success": true,
  "data": {},
  "meta": null
}
```

والخطأ:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "رسالة آمنة للمستخدم",
    "details": null,
    "requestId": "..."
  }
}
```

## قواعد إضافة endpoint

1. حدّد owner واضحًا للمسار.
2. تحقق من authentication/permission قبل الوصول للبيانات.
3. استخدم parameter binding في SQL، ولا تبنِ SQL من input خام.
4. أعد error code ثابتًا ومفيدًا دون تسريب أسرار أو stack trace.
5. أضف اختبار contract إذا كان المسار يغيّر invariant أمني أو بياناتيًا.
6. حدّث `backend/docs/PUBLIC_API_CONTRACT.md` إذا كان المسار عامًا أو جزءًا من عقد يعتمد عليه عميل خارجي.

## Unified moderation inbox (admin)

`GET /api/v1/admin/moderation/inbox?view=all&type=all&limit=500` combines student feedback (`suggestion` and general report categories) with public chat reports. Requires staff `moderation.read`. `view` is `all|current|solved|archived`; `type` is `all|suggestion|report|chat`. Updates remain type-specific: `PATCH /api/v1/admin/moderation/feedback/:id` and `PATCH /api/v1/admin/moderation/chat-reports/:id`. Both support a persistent `archived` status after migration `0044_moderation_archive.sql`.
