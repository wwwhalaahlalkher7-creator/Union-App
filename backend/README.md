# Association API v1 — Cloudflare Worker

هذه هي بداية المرحلة 3. الـWorker هو الواجهة الموحدة للتطبيق والموقع ولوحة التحكم.

## مبدأ المرحلة الحالية
الـAssociation API هو مصدر التشغيل الموحد. لا توجد اتصالات تشغيلية من التطبيق أو لوحة التحكم إلى Apps Script أو Airtable أو Sheets. أدوات الاستيراد القديمة محفوظة فقط لأغراض الترحيل التاريخي عند الحاجة.

## قبل أول نشر
1. أنشئ D1 باسم `leo-association-db`.
2. ضع `database_id` الحقيقي في `wrangler.toml`.
3. طبّق migration:
   `npx wrangler d1 migrations apply leo-association-db --remote`
4. اضبط أسرار OmniRoute فقط عند تفعيل Eino:
   `npx wrangler secret put OMNIROUTE_BASE_URL`
   `npx wrangler secret put OMNIROUTE_API_KEY`
   `npx wrangler secret put EINO_MODEL`
5. لا تضع أي secrets في Git أو Flutter.

## حالة النظام الحالية
المسارات الأساسية للـAPI موجودة الآن، مع:
- CORS
- request IDs
- أخطاء موحدة
- health + D1 check
- public content
- student session foundation
- student-scoped academic queries
- progress foundation
- comments/reactions foundation
- Eino gateway boundary

