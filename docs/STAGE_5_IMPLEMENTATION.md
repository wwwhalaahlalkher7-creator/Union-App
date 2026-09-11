# Stage 5 — Authentication

## الهدف
تحويل المصادقة من أساس تجريبي إلى طبقة قابلة للاستخدام في الإنتاج، مع فصل حسابات الطلاب عن حسابات موظفي لوحة التحكم.

## Student Auth
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `GET /api/v1/student/me`
- `GET /api/v1/student/profile`

### ترقية كلمات المرور القديمة
البيانات القديمة التي تحتوي SHA-256 تعمل مؤقتًا، وبعد أول دخول صحيح تُحوّل تلقائيًا إلى PBKDF2-SHA256 مع salt مستقل.

## Staff Auth
- `POST /api/v1/auth/staff/login`
- `POST /api/v1/auth/staff/bootstrap`
- `GET /api/v1/auth/staff/me`

أول حساب Staff يُنشأ فقط باستخدام `STAFF_BOOTSTRAP_TOKEN`. بعد وجود حساب واحد يصبح bootstrap مغلقًا.

## الحماية
- PBKDF2-SHA256 بعدد 120000 iteration للحسابات الجديدة/المُرقّاة.
- 5 محاولات فاشلة متتالية تؤدي لقفل 15 دقيقة.
- جلسات Access قصيرة 15 دقيقة وRefresh لمدة 30 يومًا.
- تدوير Refresh Token عند استخدامه.
- رفض جلسة بلا هوية أو بجمع هويتين في الوقت نفسه.
- سجل تدقيق للمصادقة بدون تخزين IP أو User-Agent بصورتهما الخام.
- صلاحيات Staff حسب الدور.

## حدود المرحلة
CRUD الخاص بلوحة التحكم لم يُفتح بعد؛ الحماية والصلاحيات جاهزة، والتنفيذ الفعلي لعمليات Dashboard يأتي في Stage 9.
