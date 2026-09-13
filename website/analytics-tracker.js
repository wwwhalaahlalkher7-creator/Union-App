/* ============================================================
   تتبع زيارات الموقع العام (analytics-tracker.js)
   ------------------------------------------------------------
   يُرسل حدث "مشاهدة صفحة" واحداً إلى Analytics-AppsScript.js عند
   تحميل كل صفحة، عبر action=log — بلا أي رمز جلسة أو كلمة سر عمداً
   (الطرف المقابل بلا حماية قصداً، راجع تعليق doGet في الملف نفسه)،
   لأن أي زائر مجهول يجب أن يستطيع إرسال هذا الحدث دون تسجيل دخول.

   الاستجابة تُتجاهل دائماً (fetch().catch(function(){})) — تتبع
   الزيارات لا يجب أبداً أن يُعطّل الصفحة أو يُظهر خطأ للزائر إن
   فشل الاتصال بالخدمة أو كانت بطيئة.
   ============================================================ */
(function () {

  // 👇 نفس رابط api.analytics.baseUrl الموجود في admin/config.js
  const ANALYTICS_URL = "https://script.google.com/macros/s/AKfycby1vOxctxnKEzrK_XS4wNfGpxOxi8XvWDIqyaLnmFZY727YFJ1Y6QNp5DieYhHXR2No2g/exec"; // ✅ محدَّث 7 أغسطس — نشر جديد بعد توحيد النشرات المتعددة

  if (!ANALYTICS_URL) return;

  /* ------------------------------------------------------------
     معرّف الزائر (vid): يبقى ثابتاً بين الزيارات على نفس المتصفح.
     معرّف الجلسة (sid): يتجدد مع كل جلسة تصفح جديدة (تبويب/نافذة).
     ------------------------------------------------------------ */
  function getOrCreateId(storage, key) {
    try {
      let id = storage.getItem(key);
      if (!id) {
        id = (crypto && crypto.randomUUID) ? crypto.randomUUID()
          : "id-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10);
        storage.setItem(key, id);
      }
      return id;
    } catch (e) {
      // خصوصية المتصفح قد تمنع localStorage/sessionStorage — لا كسر، فقط بلا معرّف ثابت
      return "";
    }
  }

  function detectDevice(ua) {
    if (/tablet|ipad/i.test(ua)) return "لوحي";
    if (/mobi|android|iphone/i.test(ua)) return "جوال";
    return "حاسوب";
  }

  function detectBrowser(ua) {
    if (/edg/i.test(ua)) return "Edge";
    if (/chrome/i.test(ua) && !/edg/i.test(ua)) return "Chrome";
    if (/firefox/i.test(ua)) return "Firefox";
    if (/safari/i.test(ua) && !/chrome/i.test(ua)) return "Safari";
    if (/opr|opera/i.test(ua)) return "Opera";
    return "غير معروف";
  }

  function detectOs(ua) {
    if (/windows/i.test(ua)) return "Windows";
    if (/android/i.test(ua)) return "Android";
    if (/iphone|ipad|ipod/i.test(ua)) return "iOS";
    if (/mac os/i.test(ua)) return "macOS";
    if (/linux/i.test(ua)) return "Linux";
    return "غير معروف";
  }

  const ua = navigator.userAgent || "";
  const vid = getOrCreateId(window.localStorage, "assoc_analytics_vid");
  const sid = getOrCreateId(window.sessionStorage, "assoc_analytics_sid");

  const payload = {
    action: "log",
    page: location.pathname.replace(/^\//, "") || "index.html",
    vid: vid,
    sid: sid,
    device: detectDevice(ua),
    browser: detectBrowser(ua),
    os: detectOs(ua),
    ref: document.referrer || ""
  };

  /* ------------------------------------------------------------
     ✅ إرسال عبر POST (جسم JSON) بدل رابط GET — بعض أدوات حجب
     الإعلانات/التتبع على جهاز الزائر تحجب روابط GET التي تحتوي
     باراميترات بأسماء تتبّعية معروفة (vid=, sid=, device=...)، بينما
     لا تراقب عادة جسم POST. لا Content-Type مخصَّص عمداً (يبقى
     text/plain الافتراضي) لتفادي طلب CORS التمهيدي (preflight) الذي
     Apps Script لا يتعامل معه — نفس أسلوب بقية نداءات POST في
     admin/js/api-adapter.js بالضبط.
     ------------------------------------------------------------ */
  fetch(ANALYTICS_URL, { method: "POST", body: JSON.stringify(payload) }).catch(function () {
    /* تجاهل — تتبع الزيارات لا يجب أن يُظهر أي خطأ للزائر */
  });
})();
