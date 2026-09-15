# إصلاح Eino عبر GitHub Secrets

رسالة `EINO_PROVIDER_AUTH` تعني أن Worker وصل إلى مزود Eino لكن المزود رفض المصادقة (HTTP 401/403). لذلك لا حاجة لتعديل واجهة Flutter لهذا الخطأ.

## المطلوب مرة واحدة

في مستودع GitHub أضف Secretين باسم:

- `OMNIROUTE_BASE_URL` — عنوان OmniRoute العام الذي يستخدمه Worker، مثل عنوان Railway الخاص بك. لا تضف `/chat/completions`؛ الكود يضيف المسار الصحيح تلقائيًا، ويقبل العنوان مع أو بدون `/v1`.
- `OMNIROUTE_API_KEY` — مفتاح API الحالي الخاص بـ OmniRoute.

لا تضع أيًا من القيمتين داخل `wrangler.toml` أو الكود.

## ماذا يفعل Workflow؟

عند Push إلى `main`:

1. يفحص الكود والمigrations.
2. يطبق D1 migrations.
3. ينشئ ملف أسرار مؤقتًا داخل Runner من GitHub Secrets.
4. ينشر Worker مع `--secrets-file`.
5. يحذف الملف فورًا.

إذا كانت الأسرار ناقصة، يتوقف الـDeploy برسالة واضحة بدل نشر Worker غير مهيأ.

> ملاحظة أمنية: لا ترسل `OMNIROUTE_API_KEY` في المحادثة ولا تحفظه في المستودع. GitHub/Cloudflare Secrets هي المكان الصحيح له.
