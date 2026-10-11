# إعداد FCM لإشعارات TRINEX

## ما الذي أُضيف؟
- Flutter يستخدم `firebase_core` و`firebase_messaging` على Android.
- يطلب إذن الإشعارات عند أول تشغيل. إذا لم يوجد إعداد Firebase، يستمر التطبيق في العمل ولا يتعطل.
- بعد تسجيل الدخول يسجل رمز الجهاز عبر `/api/v1/student/notifications/device`.
- Cloudflare Worker يعالج الإشعارات المجدولة وطابور التسليم كل دقيقة، ويرسل إشعارات الدفع إلى FCM عند ضبط السر `FCM_SERVICE_ACCOUNT_JSON`.
- لا تضع ملف حساب الخدمة أو مفتاحه الخاص داخل Flutter أو المستودع.

## أ) إعداد Firebase (مرة واحدة)
1. افتح https://console.firebase.google.com/ وأنشئ مشروعًا باسم مناسب مثل `trinex-association`.
2. من إعدادات المشروع > Your apps > Android، أضف تطبيق Android بمعرّف الحزمة `com.leoassociation.app` (يجب أن يطابق حرفيًا `applicationId` في `flutter/android/app/build.gradle`).
3. نزّل `google-services.json`. ضع الملف في المسار `flutter/android/app/google-services.json` داخل المستودع. هذا الملف خاص بإعداد التطبيق وليس مفتاح حساب الخدمة.
4. من Firebase Console > Messaging لا يلزم تفعيل أي خطة مدفوعة لإرسال FCM.

## ب) إنشاء مفتاح آمن للخادم
1. افتح Google Cloud Console المرتبط بمشروع Firebase نفسه.
2. تأكد من تفعيل **Firebase Cloud Messaging API (V1)** للمشروع.
3. أنشئ Service Account مخصصًا للإرسال وامنحه أقل صلاحية لازمة لإرسال FCM (Firebase Cloud Messaging API Admin / `cloudmessaging.messages.create` حسب إعدادات IAM المتاحة).
4. أنشئ مفتاح JSON لهذا الحساب ونزّله مؤقتًا إلى هاتفك. لا ترفعه إلى GitHub ولا تضفه إلى ZIP أو Flutter.
5. في Cloudflare Dashboard > Workers & Pages > `leo-association-api` > Settings > Variables and Secrets، أضف Secret اسمه بالضبط `FCM_SERVICE_ACCOUNT_JSON`، والصق **محتوى JSON كاملًا** للمفتاح. لا تستخدم قيمة Base64 ولا تضعها في `[vars]` أو `wrangler.toml`.
6. بعد نجاح اختبار الإرسال، احذف نسخة المفتاح المنزّلة من الهاتف، واحتفظ بالسر داخل Cloudflare فقط.

## ج) تطبيق الإعداد على المشروع
1. ارفع `google-services.json` إلى `flutter/android/app/google-services.json` في المستودع الخاص.
2. ارفع تغييرات هذا المشروع إلى GitHub، وانتظر نجاح بناء APK ونشر Worker من سير العمل الحالي. لا تنشر ملف JSON الخاص بحساب الخدمة.
3. في Cloudflare تأكد من أن Cron Trigger الخاص بالـWorker يحتوي `* * * * *` (كل دقيقة). الإعداد موجود في `backend/wrangler.toml`، لكن يجب التأكد أن النشر الفعلي التقطه.
4. اختبر باستخدام جهاز Android حقيقي: ثبّت APK الجديد، وافق على الإذن، سجّل الدخول بحساب طالب مسجل، ثم أنشئ إشعارًا تجريبيًا منشورًا من لوحة الإدارة.

## ملاحظات مهمة
- FCM نفسها مجانية. طلبات Cloudflare Worker وD1 تبقى ضمن حدود خطتك الحالية. الجدولة تستخدم تشغيلًا مجدولًا كل دقيقة؛ المعالجة محدودة بـ20 إعلانًا مستحقًا و50 عملية تسليم في كل تشغيل لتخفيف الحمل.
- الإشعارات داخل التطبيق تُقرأ من D1 حتى لو لم يكن الهاتف مثبتًا عليه التطبيق أو لم يمنح الإذن. إشعارات الدفع تحتاج إلى جهاز مسجل ورمز صالح وإذن من النظام.
- Android قد يؤخر الإشعار بسبب وضع توفير الطاقة أو انقطاع الإنترنت.
- هذا الإعداد يجهّز Android. دعم iOS يحتاج إضافة تطبيق iOS في Firebase وإعداد `GoogleService-Info.plist` وتكوين APNs قبل تفعيل الدفع على iPhone.
- لا تستخدم ملف Service Account JSON في أي مكان داخل التطبيق. إذا تسرب، ألغِ المفتاح فورًا وأنشئ واحدًا جديدًا.
