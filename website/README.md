# TRINEX Website

هذا المجلد هو جذر الموقع العام. ضع ملفات الموقع الحالي (HTML / CSS / JS) مباشرة هنا.

- الموقع العام: `https://ush-eng.great-site.net`
- لوحة الإدارة: `https://ush-eng.great-site.net/admin/`
- API: `https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## البنية

```text
website/
├── ملفات الموقع العام (HTML/CSS/JS)
└── dashboard/
    ├── ملفات لوحة الإدارة
    └── worker/
```

الموقع العام هو الأصل، و`/admin/` هو المسار المخصص للوحة الإدارة.

> في المرحلة الحالية ملفات الموقع العام لم تُنقل بعد، لذلك يبقى اعتماد الموقع على Apps Script كما هو. بعد وضع الملفات هنا سيتم تحويل طبقة البيانات تدريجيًا إلى API الخاص بـTRINEX.
