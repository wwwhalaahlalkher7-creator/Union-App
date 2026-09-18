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
| Public content | `/public/news`, `/public/events`, `/public/activities`, `/public/announcements`, `/public/achievements`, `/public/materials` | عامة |
| Auth | `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/staff/login` | حسب المسار |
| Student | `/student/me`, `/student/stats`, `/student/notifications` | Student session |
| Academic | `/semesters`, `/departments`, `/subjects`, `/materials`, `/schedule` | بعض المسارات محمية |
| Progress | `/progress`, `/xp`, `/badges` | Student session |
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
