# المرحلة 6 — Google Drive Content Indexer

تم نقل فكرة فهرسة المواد من Apps Script/DriveApp إلى طبقة مستقلة داخل Cloudflare Worker.

## البنية

Google Drive → Cloudflare Worker → D1

يستخدم الـ Worker حساب خدمة Google عبر OAuth 2.0 JWT، لذلك لا توجد مفاتيح Google داخل التطبيق أو المستودع.

## المتطلبات السرية

اضبط الأسرار التالية في Worker:

- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`
- `GOOGLE_DRIVE_ROOT_FOLDER_ID`

ويجب مشاركة مجلد المواد الرئيسي مع البريد الخاص بحساب الخدمة بصلاحية قراءة.

## بنية Drive المتوقعة

```text
المواد الدراسية/
  القسم/
    الفصل/
      المادة/
        *.pdf
```

تُطابق أسماء الأقسام والفصول مع سجلات D1. مجلد المادة يتحول إلى `subject`، وكل PDF يتحول إلى `material`.

## API

### تشغيل مزامنة

`POST /api/v1/admin/drive/sync`

يتطلب جلسة موظف بصلاحية `Super Admin` أو `Academic Manager`.

### حالة آخر عمليات المزامنة

`GET /api/v1/admin/drive/sync-status`

## قواعد مهمة

- المزامنة لا تحذف بيانات D1 فعليًا؛ الملفات التي اختفت من Drive تُعطّل (`active=0`).
- الملفات الجديدة أو المعدلة تُحدّث تلقائيًا.
- `drive_file_id` هو المفتاح الخارجي الأساسي لملف Drive.
- يتم حفظ `modifiedTime` و`webViewLink` و`pinned`.
- لا يقبل الـ Worker أي XP من Drive أو العميل.
- لا توجد أي عودة إلى نظام الإعلانات التجارية.

## تشغيل تلقائي لاحقًا

يمكن استدعاء endpoint من Cron/Workflow بعد تفعيل النشر. المرحلة الحالية تركز على indexer نفسه؛ جدولة المزامنة وتشغيلها من Dashboard تأتي ضمن التشغيل الإداري الكامل.
