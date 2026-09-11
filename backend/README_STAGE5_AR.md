# المرحلة 5 — المصادقة النهائية للطلاب وموظفي الإدارة

## ما أضيف
- تسجيل دخول الطلاب مع ترقية تلقائية من SHA-256 القديم إلى PBKDF2-SHA256 عند أول دخول ناجح.
- تسجيل دخول موظفي الإدارة عبر `/api/v1/auth/staff/login`.
- تهيئة أول Super Admin مرة واحدة عبر `/api/v1/auth/staff/bootstrap` باستخدام `STAFF_BOOTSTRAP_TOKEN`.
- جلسات مشتركة في D1 مع تمييز جلسة الطالب عن جلسة الموظف.
- قفل مؤقت بعد 5 محاولات فاشلة لمدة 15 دقيقة.
- سجل تدقيق للمحاولات الناجحة والفاشلة، مع تخزين hash للـ IP وUser-Agent بدل القيم الخام.
- صلاحيات أدوار الإدارة الأساسية.
- لا توجد أسرار داخل المستودع.

## متغيرات التشغيل
- `ALLOWED_ORIGINS`
- `STAFF_BOOTSTRAP_TOKEN` — Secret، وليس Variable عاديًا.
- `OMNIROUTE_BASE_URL` — Secret/Variable حسب بيئة النشر.
- `OMNIROUTE_API_KEY` — Secret.
- `EINO_MODEL` — Variable بعد التحقق من النموذج المدعوم في Leo-OmniRoute.

## تهيئة أول مدير
بعد تطبيق migrations، اضبط `STAFF_BOOTSTRAP_TOKEN` ثم أرسل طلبًا واحدًا إلى:
`POST /api/v1/auth/staff/bootstrap`
مع header:
`X-Staff-Bootstrap-Token: <token>`

Body:
```json
{"email":"admin@example.com","displayName":"مدير الرابطة","password":"كلمة مرور قوية لا تقل عن 10 أحرف"}
```

بعد إنشاء أول مدير، endpoint التهيئة يصبح مغلقًا نهائيًا طالما يوجد حساب staff واحد على الأقل.

## ملاحظة مهمة
المسارات الإدارية أصبحت محمية بالمصادقة والصلاحيات، لكن CRUD الخاص بالـ Dashboard سيُنفذ في مرحلة ترحيل Dashboard. لا يتم فتح CRUD قبل تلك المرحلة.
