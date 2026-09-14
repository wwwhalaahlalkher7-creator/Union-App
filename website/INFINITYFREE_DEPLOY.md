# نشر الموقع + لوحة التحكم على InfinityFree

هذه الحزمة هي الواجهة الثابتة فقط. الـBackend وقاعدة D1 وEino/OmniRoute تبقى على Cloudflare.

## البنية المطلوبة داخل `htdocs`

```text
htdocs/
├── index.html
├── news.html
├── activities.html
├── courses.html
├── ...
└── admin/
    ├── index.html
    ├── login.html
    ├── users.html
    └── ...
```

- ارفع **محتويات حزمة InfinityFree** إلى `htdocs`، وليس مجلد `website` نفسه.
- لوحة التحكم ستكون على `/admin/`.
- عنوان الـAPI يبقى `https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1` في إعدادات الواجهة.
- لا ترفع مجلدي `worker/` ولا ملفات `wrangler.toml` إلى InfinityFree؛ هذه خاصة بنشر Cloudflare القديم للموقع.

المصدر الكامل للموقع والـDashboard يبقى داخل المستودع تحت `website/`، بينما هذه الحزمة مجرد نسخة نشر مستقلة.
