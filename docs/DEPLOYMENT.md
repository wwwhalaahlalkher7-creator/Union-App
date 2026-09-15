# Deployment Runbook

## المسار الطبيعي

```text
push main
   ├── Flutter CI → analyze/test → Android APK/AAB
   ├── Backend CI → syntax/contracts/migrations → Cloudflare Worker + D1
   └── Website CI → validate/package → InfinityFree
```

## Backend

Workflow: `.github/workflows/backend.yml`

يعمل على `main` ويقوم بـ:

1. تثبيت Node.
2. فحص syntax.
3. تشغيل contract checks.
4. تطبيق D1 migrations.
5. نشر Worker مع Eino secrets.

## Flutter

Workflow: `.github/workflows/flutter.yml`

يستخدم Flutter stable `3.47.2` حاليًا، ويشغّل analyze/test ثم يبني APK/AAB. على `main` يتطلب production signing secrets.

## Website

Workflow: `.github/workflows/deploy-website.yml`

يتحقق من JavaScript والملفات المطلوبة وسياسة المصادر القديمة، ثم ينشر الموقع ولوحة الإدارة إلى InfinityFree عبر FTPS.

## تحقق بعد النشر

### API

```text
GET /api/v1/health
GET /api/v1/version
```

تحقق من:

- `status` في health.
- اتصال D1.
- `apiVersion`.
- `appVersion` و`minimumAppVersion`.

### Website

تحقق من:

- الصفحة الرئيسية.
- `/admin/`.
- تسجيل دخول الإدارة.
- تحميل المحتوى من API.

### Eino

اختبر طلبًا عاديًا من التطبيق، ثم راقب `admin/security/eino-usage` إذا كان لديك صلاحية الإدارة.

## Rollback

لا تعكس migration بإعادة تسمية أو حذف الملف. عند وجود migration خاطئة، أنشئ migration تصحيحية.

للتطبيق/الموقع، استخدم Git commit معروفًا ثم أعد النشر بعد التأكد من توافق D1/API.

## Signing

لا يتم تضمين keystore في المستودع. تحديث Android فوق نسخة منشورة يتطلب نفس مفتاح توقيع الإنتاج و`versionCode` أعلى.
