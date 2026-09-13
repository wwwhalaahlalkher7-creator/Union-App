# TRINEX Website

هذا المجلد هو جذر الموقع العام. ملفات الموقع العام هنا تعتمد على TRINEX Public API للقراءة فقط.

- الموقع العام: `https://ush-eng.great-site.net`
- لوحة الإدارة: `https://ush-eng.great-site.net/admin/` (تُخدم من نفس نشر الموقع)
- API: `https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## البنية

```text
website/
├── ملفات الموقع العام (HTML/CSS/JS)
└── dashboard/
    ├── ملفات لوحة الإدارة
    └── worker/
```

الموقع العام هو الأصل، و`/admin/` هو المسار المخصص للوحة الإدارة. كلاهما يُنشران معاً من Worker واحد.

> تم نقل طبقة القراءة العامة إلى TRINEX Public API. الموقع العام لا يملك حساب طالب ولا تفاعلًا عامًا، ولا يعتمد تشغيليًا على Apps Script أو Airtable أو نظام الإعلانات التجاري. المواد الدراسية تُقرأ من `/public/materials`، والمحتوى من endpoints `/public/*`.
