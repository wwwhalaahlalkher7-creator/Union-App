/* ============================================================
   لون هوية لوحة التحكم (AdminThemeColor)
   ------------------------------------------------------------
   ✅ جديد — يجعل لون اللوحة (عائلة --blueprint-* في admin.css)
   قابلاً للتغيير فعلياً من "إعدادات الموقع" > "ألوان الهوية"، بلا
   إعادة رفع أي ملف. يُحمَّل في <head> كل صفحة، بعد config.js
   وقبل رسم الجسم، حتى لا تظهر "ومضة" اللون الافتراضي القديم.

   الآلية:
   1) يقرأ فوراً آخر لون محفوظ محلياً (localStorage) ويطبّقه — بلا
      أي انتظار شبكة، يعمل حتى بلا اتصال.
   2) بالتوازي، يجلب أحدث قيمة فعلية من الخادم عبر
      action=getPublicSettings في Backup-Settings-AppsScript.js
      (بلا رمز جلسة عمداً — راجع نفس المسار في site-settings.js
      بالموقع العام؛ أي مستخدم مسجَّل دخول بأي دور يحتاج هذا اللون
      قبل حتى معرفة دوره)، ويحدّث الصفحة + الذاكرة المحلية إن تغيّر.
   ============================================================ */
window.AdminTheme = (function () {
  const CACHE_KEY = "assoc_admin_theme_color";

  function hexToRgb_(hex) {
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return m ? { r: parseInt(m[1], 16), g: parseInt(m[2], 16), b: parseInt(m[3], 16) } : null;
  }
  function rgbToHex_(r, g, b) {
    return "#" + [r, g, b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("");
  }
  /** يمزج لوناً مع أبيض/أسود بنسبة amount (0..1) لتوليد درجات أفتح/أغمق تلقائياً */
  function mix_(hex, target, amount) {
    const c = hexToRgb_(hex);
    if (!c) return hex;
    const t = hexToRgb_(target);
    return rgbToHex_(c.r + (t.r - c.r) * amount, c.g + (t.g - c.g) * amount, c.b + (t.b - c.b) * amount);
  }

  /** يطبّق لوناً أساسياً واحداً على كل عائلة --blueprint-* دفعة واحدة (المولّد الأساسي = blueprint-600) */
  function apply(baseHex) {
    if (!/^#[0-9a-fA-F]{6}$/.test(baseHex)) return;
    const root = document.documentElement.style;
    root.setProperty("--blueprint-600", baseHex);
    root.setProperty("--blueprint-500", mix_(baseHex, "#ffffff", 0.18));
    root.setProperty("--blueprint-700", mix_(baseHex, "#000000", 0.15));
    root.setProperty("--blueprint-900", mix_(baseHex, "#000000", 0.35));
    root.setProperty("--blueprint-100", mix_(baseHex, "#ffffff", 0.88));
    try { localStorage.setItem(CACHE_KEY, baseHex); } catch (e) { /* تجاهل */ }
  }

  function previewSite(hex) {
    if (!/^#[0-9a-fA-F]{6}$/.test(hex)) return;
    const m = hexToRgb_(hex);
    if (!m) return;
    const glow = "#" + [m.r,m.g,m.b].map(v => Math.max(0, Math.min(255, Math.round(v + (255-v)*.3))).toString(16).padStart(2,"0")).join("");
    const root = document.documentElement.style;
    root.setProperty("--primary", hex);
    root.setProperty("--primary-glow", glow);
    root.setProperty("--primary-rgb", [m.r,m.g,m.b].join(", "));
  }

  function boot() {
    try {
      const cached = localStorage.getItem(CACHE_KEY);
      if (cached) apply(cached);
    } catch (e) { /* تجاهل */ }

    const cfg = window.APP_CONFIG;
    if (!base) return; // لا خدمة مضبوطة بعد — يبقى اللون الافتراضي في admin.css

    fetch(base + "?action=getPublicSettings")
      .then(r => r.json())
      .then(data => {
        if (data && data.success && data.settings && data.settings.AdminThemeColor) {
          apply(data.settings.AdminThemeColor);
        }
      })
      .catch(() => { /* تجاهل — يبقى اللون المحفوظ محلياً أو الافتراضي */ });
  }

  boot();
  return { apply, previewSite };
})();
