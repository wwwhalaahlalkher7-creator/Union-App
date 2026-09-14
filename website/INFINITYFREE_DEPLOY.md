# نشر الموقع + لوحة التحكم على InfinityFree

الموقع العام ولوحة التحكم يتم نشرهما تلقائيًا من GitHub Actions إلى InfinityFree عبر FTPS.

## المطلوب مرة واحدة فقط

أضف هذه **Repository Secrets** في GitHub:

- `INFINITYFREE_FTP_USERNAME` — اسم مستخدم FTP لحساب InfinityFree.
- `INFINITYFREE_FTP_PASSWORD` — كلمة مرور FTP.
- `INFINITYFREE_FTP_REMOTE_DIR` — المسار البعيد للموقع، وغالبًا `htdocs/` للموقع الرئيسي. إذا تركته بدون قيمة سيستخدم الـ workflow `htdocs/` تلقائيًا.

لا تضع كلمة المرور داخل ملفات المشروع أو الـ workflow.

InfinityFree يستخدم مضيف FTP مستقلًا عن الدومين؛ المضيف المستخدم في الـ workflow هو `ftpupload.net`، وليس `ush-eng.great-site.net`.

## بعد الإعداد

أي `push` إلى `main` يغيّر ملفات `website/` سيؤدي إلى:

1. فحص JavaScript وملفات الموقع والـ Dashboard.
2. تجهيز نسخة الموقع العام داخل الجذر وDashboard داخل `/admin/`.
3. نشر الملفات تلقائيًا إلى InfinityFree عبر FTPS.
4. الاحتفاظ أيضًا بحزمة ZIP كـ GitHub Actions artifact.

لا يحتاج المستخدم بعد ذلك إلى تحميل ZIP ورفعه يدويًا في كل تحديث.

## البنية

```text
InfinityFree
└── htdocs/
    ├── index.html
    ├── news.html
    ├── ...
    └── admin/
        ├── index.html
        ├── login.html
        └── ...
```

أما الـ Backend وD1 وEino/OmniRoute فما زالت على البنية السحابية الحالية، ولا يتم رفعها إلى InfinityFree.
