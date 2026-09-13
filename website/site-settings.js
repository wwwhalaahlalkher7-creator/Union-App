/* ============================================================
   ربط صفحات الموقع العام بإعدادات الموقع (site-settings.js)
   ------------------------------------------------------------
   يقرأ اسم الموقع/الجامعة/التواصل/نصوص الرئيسية من الخدمة الخامسة
   Backup-Settings-AppsScript.js عبر action=getPublicSettings —
   طلب GET بلا رمز جلسة أو كلمة سر (نفس فلسفة action=log في
   Analytics-AppsScript.js)، لأن هذه القيم عرض عام أصلاً ولا يوجد
   مستخدم مسجَّل دخول في الموقع العام ليحمل رمزاً.

   يبحث عن عناصر بهذه المعرّفات (id) في الصفحة الحالية، ويملأ ما
   وُجد منها فقط — الصفحات المختلفة تحتوي مجموعات فرعية مختلفة
   (index.html فقط فيها hero وروابط التواصل، بينما كل الصفحات فيها
   شعار الرأس وتذييل الحقوق).

     #siteLogoName        عنصر <h2> اسم الرابطة في شعار الرأس
     #footerSiteName       اسم الرابطة داخل جملة تذييل الحقوق
     #footerUniversity     اسم الجامعة داخل جملة تذييل الحقوق
     #heroTitle             عنوان قسم الـ Hero (index.html فقط)
     #heroSubtitle          فقرة قسم الـ Hero (index.html فقط)
     #contactEmailLink      رابط mailto: (index.html فقط)
     #contactWhatsappLink   رابط wa.me/ (index.html فقط)
     #contactFacebookLink   رابط فيسبوك (index.html فقط)
     #contactTwitterLink    رابط تويتر/X، إن وُجد العنصر مستقبلاً
     #contactInstagramLink  رابط إنستغرام، إن وُجد العنصر مستقبلاً
     #contactTelegramLink   رابط تيليغرام، إن وُجد العنصر مستقبلاً

   ⚠️ **بلا كسر أبداً**: كل عنصر مذكور أعلاه يحمل بالفعل النص/الرابط
   الحقيقي الحالي كقيمة افتراضية ثابتة في HTML. إن كان SITE_SETTINGS_URL
   فارغاً أدناه، أو تعذّر الاتصال بالخدمة، أو رجعت القيمة فارغة —
   يبقى العنصر بمحتواه الثابت الحالي دون أي تغيير. الاستبدال يحدث
   فقط بعد نجاح الجلب الفعلي.
   ============================================================ */
(function () {

  // اللون الأصلي لهوية الموقع — يستخدم كافتراضي ويستبدل فقط قيمة البنفسجي القديمة من v4.
  const DEFAULT_THEME_COLOR = "#ff9100";
  const LEGACY_THEME_COLOR = "#7c5cff";

  // 👇 رابط Backup-Settings-AppsScript.js المؤكد عمله (زوّده المستخدم).
  //    ⚠️ لا يزال يعتمد على أن action=getPublicSettings الجديد مُعاد
  //    نشره فعليًا على هذا الرابط (Deploy → New version) — راجع
  //    CLAUDE_CONTEXT.md.
  const SITE_SETTINGS_URL = "https://script.google.com/macros/s/AKfycbxMoaJoDkd18koFfySF3UkpV4EM4YG5gxfNvJ0e_RL7WMLuzBUMiWvQXou1JTlIQnsS/exec";

  if (!SITE_SETTINGS_URL) return;

  function setText(id, value) {
    if (!value) return;
    const el = document.getElementById(id);
    if (el) el.textContent = value;
  }

  function setHref(id, value) {
    if (!value) return;
    const el = document.getElementById(id);
    if (el) el.setAttribute("href", value);
  }

  /** ✅ جديد — يطبّق لون الهوية (SiteThemeColor) على --primary و--primary-glow في كل صفحات الموقع العام */
  function hexToRgb_(hex) {
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex || "");
    return m ? { r: parseInt(m[1], 16), g: parseInt(m[2], 16), b: parseInt(m[3], 16) } : null;
  }
  function setThemeColor(hex) {
    if (!/^#[0-9a-fA-F]{6}$/.test(hex || "")) return;
    const c = hexToRgb_(hex);
    const glow = "#" + [c.r, c.g, c.b].map(v => Math.max(0, Math.min(255, Math.round(v + (255 - v) * 0.3))).toString(16).padStart(2, "0")).join("");
    const rgb = [c.r, c.g, c.b].join(", ");
    document.documentElement.style.setProperty("--primary", hex);
    document.documentElement.style.setProperty("--primary-glow", glow);
    document.documentElement.style.setProperty("--primary-rgb", rgb);
    try { localStorage.setItem("assoc_site_theme_color", hex); } catch (e) { /* تجاهل */ }
  }

  // تطبيق فوري للون المحفوظ محلياً من زيارة سابقة (بلا وميض)، قبل حتى وصول رد الخادم
  try {
    const cached = localStorage.getItem("assoc_site_theme_color");
    if (cached && cached.toLowerCase() !== LEGACY_THEME_COLOR) setThemeColor(cached);
    else setThemeColor(DEFAULT_THEME_COLOR);
  } catch (e) { /* تجاهل */ }

  fetch(SITE_SETTINGS_URL + "?action=getPublicSettings")
    .then(function (res) { return res.json(); })
    .then(function (data) {
      if (!data || !data.success || !data.settings) return;
      const s = data.settings;

      const serverColor = (s.SiteThemeColor || "").toLowerCase();
      setThemeColor(serverColor === LEGACY_THEME_COLOR ? DEFAULT_THEME_COLOR : (s.SiteThemeColor || DEFAULT_THEME_COLOR));
      setText("siteLogoName", s.SiteName);
      setText("footerSiteName", s.SiteName);
      setText("footerUniversity", s.University);
      setText("heroTitle", s.HeroTitle);
      setText("heroSubtitle", s.HeroSubtitle);

      if (s.ContactEmail) setHref("contactEmailLink", "mailto:" + s.ContactEmail);
      if (s.ContactPhone) {
        const digits = s.ContactPhone.toString().replace(/[^0-9]/g, "");
        if (digits) setHref("contactWhatsappLink", "https://wa.me/" + digits);
      }
      setHref("contactFacebookLink", s.Facebook);
      setHref("contactTwitterLink", s.Twitter);
      setHref("contactInstagramLink", s.Instagram);
      setHref("contactTelegramLink", s.Telegram);
    })
    .catch(function () {
      /* تجاهل — الصفحة تبقى بنصوصها/روابطها الثابتة الحالية */
    });
})();
