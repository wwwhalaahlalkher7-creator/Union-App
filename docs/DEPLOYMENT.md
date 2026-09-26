# Deployment Runbook

## المسار الطبيعي

```text
push main
   ├── Flutter CI → analyze/test → Android APK/AAB
   ├── Backend CI → syntax/contracts/migrations → Cloudflare Worker + D1
   └── Website CI → validate/package → InfinityFree
```

## Backend

Workflow: `.github/workflows/release.yml` (job: `backend-deploy`)

يعمل على `main` ويقوم بـ:

1. تثبيت Node.
2. فحص syntax.
3. تشغيل contract checks.
4. تطبيق D1 migrations.
5. نشر Worker مع Eino secrets.

## Flutter

Workflow: `.github/workflows/release.yml` (job: `flutter-build`)

يستخدم Flutter stable، ويشغّل analyze/test على كل push/PR، ويبني APK/AAB موقّعين بالإنتاج على `main` فقط. الـproduction signing secrets مطلوبة لبناء artifacts النهائية.

## Website

Workflow: `.github/workflows/release.yml`

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
