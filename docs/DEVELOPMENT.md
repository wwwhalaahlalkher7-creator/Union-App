# Development & Maintenance

## قواعد العمل

- استخدم Git branch أو commit واضح لكل تغيير منطقي.
- لا تعدّل production مباشرةً لإصلاح مشكلة يمكن اختبارها في الكود.
- لا تعدّل migrations قديمة.
- لا تضع بيانات اختبار حقيقية في repository.
- لا تعتمد على وثيقة مرحلة قديمة؛ ارجع إلى هذه الوثائق والكود الحالي.

## Flutter

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
```

للبناء:

```bash
flutter build apk --release
flutter build appbundle --release
```

الإصدار يُغيّر من `flutter/VERSION` فقط، ثم تتم مزامنة `pubspec.yaml` و`lib/core/app_version.dart` عبر:

```bash
cd flutter
python3 tool/sync_version.py
```

## Backend

```bash
cd backend
npm install --no-audit --no-fund
node --check src/index.js
npm run migrate:local
```

للتطوير المحلي:

```bash
cd backend
npm run dev
```

## D1 migrations

إنشاء migration جديدة:

```text
backend/migrations/0019_short_description.sql
```

اختبارها محليًا:

```bash
cd backend
npm run migrate:local
```

التطبيق على الإنتاج يتم من GitHub Actions أو بعد مراجعة صريحة:

```bash
npm run migrate:remote
```

## Contract checks

من جذر المستودع:

```bash
python3 ci/verify_project.py
python3 ci/release_check.py
python3 ci/final_release_check.py
python3 ci/admin_crud_check.py
python3 ci/auth_hardening_check.py
python3 ci/eino_dashboard_check.py
python3 ci/web_security_check.py
python3 ci/xss_dom_check.py
python3 ci/flutter_secure_storage_check.py
```

## عند إصلاح bug

1. حدّد الطبقة المالكة للمشكلة.
2. أضف regression check إذا كان الخطأ قابلًا للتكرار.
3. أصلح المصدر، لا العرض فقط.
4. شغّل الاختبار الأقرب ثم suite المناسب.
5. حدّث الوثيقة التشغيلية فقط إذا تغير behavior أو procedure.
6. اكتب commit يصف السبب والنتيجة.

## ما لا نفعله

- لا نضيف README باسم Stage جديد.
- لا نكرر نفس secret instructions في عدة ملفات.
- لا ننسخ API URL في عشرات الملفات دون سبب.
- لا نحذف migration مطبقة.
- لا نضع أسرار AI أو signing في التطبيق.
