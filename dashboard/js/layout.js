/* ============================================================
   الهيكل العام المشترك للوحة (Sidebar + Topbar)
   ------------------------------------------------------------
   كل صفحة في اللوحة تتضمّن فقط:
     <div id="app-shell"></div>
     <script src="js/layout.js"></script>
   وهذا الملف يحقن الشريط الجانبي والعلوي تلقائياً، ويحدّد العنصر
   النشط بحسب body[data-page]. مصدر واحد للتنقل = صيانة أسهل،
   بلا تكرار لنفس الـ HTML في كل صفحة (كما هو حال الموقع العام حالياً).
   ============================================================ */

(function () {
  const cfg = window.APP_CONFIG;

  const NAV_ITEMS = [
    { key: "dashboard",   label: "الرئيسية",           icon: "fa-gauge-high",     href: "index.html" },
    { key: "students",    label: "الطلاب",              icon: "fa-user-graduate",   href: "students.html" },
    { key: "schedule",    label: "الجداول الدراسية",     icon: "fa-calendar-days",  href: "schedule.html" },
    { key: "materials",   label: "المواد الدراسية",      icon: "fa-folder-open",    href: "materials.html" },
    { key: "news",        label: "المحتوى",             icon: "fa-newspaper",      href: "content.html" },
    { key: "moderation",  label: "الإشراف",             icon: "fa-comments",       href: "moderation.html" },
    { key: "users",       label: "المستخدمون",          icon: "fa-user-shield",    href: "users.html" },
    { key: "security",    label: "الأمان",              icon: "fa-lock",           href: "security.html" },
    { key: "settings",    label: "إعدادات الموقع",      icon: "fa-gear",           href: "settings.html" }
  ];

  const PAGE_TITLES = NAV_ITEMS.reduce((map, item) => {
    map[item.key] = item.label;
    return map;
  }, {});
  // "حسابي" ليست في الشريط الجانبي (متاحة لكل الأدوار عبر رابط في الشريط العلوي فقط)
  PAGE_TITLES.account = "حسابي";

  /** الوحدات المسموح بها لكل دور — دور غير معروف (أو معاينة بلا جلسة) يُعامل كمشاهد فقط */
  const ROLE_NAV_KEYS = {
    "super_admin": null,
    "content_manager": ["dashboard", "news"],
    "academic_manager": ["dashboard", "students", "schedule", "materials"],
    "moderator": ["dashboard", "moderation"]
  };

  const ROLE_ACCESS_KEYS = {
    "super_admin": null,
    "content_manager": ["dashboard", "news", "account"],
    "academic_manager": ["dashboard", "students", "schedule", "materials", "account"],
    "moderator": ["dashboard", "moderation", "account"]
  };

  const ROLE_LABELS = {
    "super_admin": "لديك صلاحية الوصول إلى جميع أقسام اللوحة.",
    "content_manager": "هذا القسم خارج نطاق صلاحيات محرر المحتوى.",
    "academic_manager": "هذا القسم خارج نطاق صلاحيات المسؤول الأكاديمي.",
    "moderator": "هذا القسم خارج نطاق صلاحيات المشرف.",
  };

  function canAccess(key, role) {
    const allowed = ROLE_ACCESS_KEYS.hasOwnProperty(role) ? ROLE_ACCESS_KEYS[role] : [];
    return allowed === null || allowed.includes(key);
  }

  function friendlyDenied(key, role) {
    const names = PAGE_TITLES[key] || "هذا القسم";
    const messages = {
      "محرر محتوى": `هذا القسم (${names}) خارج نطاق حساب محرر المحتوى. 🌿 أنت لا تحتاجه لإنجاز مهامك، لذلك لن نزعجك بتحويلك إليه.`,
      "مسؤول أكاديمي": `هذا القسم (${names}) تابع لأمانة الإعلام. 🔒 صلاحياتك الأكاديمية تعمل بشكل طبيعي، لكن هذا القسم ليس ضمن نطاق حسابك.`,
      "مشاهد فقط": `هذا القسم (${names}) يحتاج صلاحية أعلى. 👀 يمكنك الاستمرار في الأقسام المتاحة لك دون أي مشكلة.`,
    };
    const message = messages[role] || `هذا القسم (${names}) غير متاح لهذا الحساب. 🔒`;
    if (typeof Feedback !== "undefined" && Feedback.info) Feedback.info(message);
    else window.alert(message);
  }

  window.RoleGuard = { canAccess, friendlyDenied };

  function guardPageAccess(activeKey, role) {
    const allowed = ROLE_ACCESS_KEYS.hasOwnProperty(role) ? ROLE_ACCESS_KEYS[role] : [];
    if (allowed === null || allowed.includes(activeKey) || activeKey === "account") return true;
    // لا نعيد المستخدم بصمت: أعطه سبباً واضحاً ووقتاً كافياً لقراءته.
    const message = (ROLE_LABELS[role] || "هذا القسم غير متاح لهذا الحساب.") + ` — القسم: ${PAGE_TITLES[activeKey] || activeKey}`;
    try { sessionStorage.setItem("assoc_denied_notice", message); } catch (e) {}
    if (typeof Feedback !== "undefined" && Feedback.info) Feedback.info(message, 7000);
    setTimeout(() => location.replace("index.html"), 4800);
    return false;
  }

  function buildNavHtml(activeKey, role) {
    const allowedKeys = ROLE_NAV_KEYS.hasOwnProperty(role) ? ROLE_NAV_KEYS[role] : [];
    return NAV_ITEMS
      .filter(item => cfg.modules[item.key] !== false)
      .filter(item => !allowedKeys || allowedKeys.includes(item.key))
      .map(item => {
        const active = item.key === activeKey ? " is-active" : "";
        return (
          '<a class="sidebar-link' + active + '" href="' + item.href + '"' + (item.key === activeKey ? ' aria-current="page"' : '') + '>' +
            '<i class="fa-solid ' + item.icon + '"></i>' +
            '<span>' + item.label + '</span>' +
          '</a>'
        );
      })
      .join("");
  }

  function buildShellHtml(activeKey, session) {
    const title = PAGE_TITLES[activeKey] || "";
    const userName = (session && session.name) || "زائر";
    const userRole = (session && session.role) || "غير مصرح";
    return `
      <div class="sidebar" id="sidebar">
        <div class="sidebar-brand">
          <div class="sidebar-brand-logo sidebar-brand-mark" aria-hidden="true"><i class="fa-solid fa-building-columns"></i></div>
          <div class="sidebar-brand-text">
            <strong>${cfg.site.shortName}</strong>
            <span>${cfg.site.org}</span>
          </div>
        </div>

        <nav class="sidebar-nav">
          ${buildNavHtml(activeKey, userRole)}
        </nav>
      </div>

      <div class="app-overlay" id="appOverlay"></div>

      <div class="main-area">
        <header class="topbar">
          <button class="icon-btn topbar-menu-btn" id="menuBtn" aria-label="فتح القائمة">
            <i class="fa-solid fa-bars"></i>
          </button>
          <h1 class="topbar-title">${title}</h1>

          <div class="topbar-actions">
            <a href="${cfg.site.publicUrl}" class="icon-btn" target="_blank" title="عرض الموقع">
              <i class="fa-solid fa-arrow-up-right-from-square"></i>
            </a>
            <a href="account.html" class="topbar-user" title="حسابي — تغيير كلمة المرور">
              <div class="topbar-user-avatar"><i class="fa-solid fa-user"></i></div>
              <span class="topbar-user-copy"><span class="topbar-user-name">${userName}</span><span class="topbar-role">${userRole}</span></span>
            </a>
            <button class="icon-btn" id="logoutBtn" title="تسجيل الخروج">
              <i class="fa-solid fa-arrow-right-from-bracket"></i>
            </button>
          </div>
        </header>

        <main class="page-content" id="pageContent"></main>
      </div>
    `;
  }

  function initRoleGuardLinks() {
    if (window.__assocRoleGuardBound) return;
    window.__assocRoleGuardBound = true;
    document.addEventListener("click", function (event) {
      const link = event.target && event.target.closest ? event.target.closest("[data-role-key]") : null;
      if (!link) return;
      const session = (typeof Auth !== "undefined" && Auth.get) ? Auth.get() : null;
      const key = link.getAttribute("data-role-key");
      if (!canAccess(key, session && session.role)) {
        event.preventDefault();
        event.stopImmediatePropagation();
        friendlyDenied(key, session && session.role);
      }
    }, true);
  }

  function initMobileToggle() {
    const sidebar = document.getElementById("sidebar");
    const overlay = document.getElementById("appOverlay");
    const menuBtn = document.getElementById("menuBtn");
    const closeBtn = document.getElementById("sidebarCloseBtn");

    function close() {
      sidebar.classList.remove("is-open");
      overlay.classList.remove("is-visible");
    }
    menuBtn.addEventListener("click", () => {
      sidebar.classList.add("is-open");
      overlay.classList.add("is-visible");
    });
    overlay.addEventListener("click", close);
    if (closeBtn) closeBtn.addEventListener("click", close);
    sidebar.querySelectorAll("a").forEach(link => link.addEventListener("click", close));
  }

  function initTopbarScroll() {
    const topbar = document.querySelector(".topbar");
    if (!topbar) return;
    const sync = () => topbar.classList.toggle("is-scrolled", window.scrollY > 4);
    sync();
    window.addEventListener("scroll", sync, { passive: true });
  }

  function initLogout() {
    const btn = document.getElementById("logoutBtn");
    btn.addEventListener("click", async () => {
      const session = (typeof Auth !== "undefined") ? Auth.get() : null;
      if (session && typeof Adapter !== "undefined" && Adapter.logoutSession) {
        try { await Adapter.logoutSession(session.token); } catch (e) { /* تجاهل — الانتهاء التلقائي يكفي */ }
      }
      if (typeof Auth !== "undefined") Auth.logout();
      else { localStorage.removeItem("assoc_admin_session"); location.href = "login.html"; }
    });
  }

  function mount() {
    const activeKey = document.body.getAttribute("data-page") || "dashboard";
    const shell = document.getElementById("app-shell");
    if (!shell) return;

    const session = (typeof Auth !== "undefined") ? Auth.get() : null;
    const role = (session && session.role) || "";
    if (!guardPageAccess(activeKey, role)) return;

    // ✅ جديد — تمييز واجهة "مدير عام" حصراً لإظهار عناصر مقصورة عليه
    // فقط (مثل حذف محاولات الدخول الفاشلة في security.html) — راجع
    // .requires-admin في admin.css. لاحظ: هذا تحكم واجهة فقط، الحماية
    // الفعلية على الخادم عبر requireAdminSession_.
    document.body.classList.toggle("role-admin", !!session && session.role === "مدير عام");
    document.body.classList.toggle("role-academic", !!session && session.role === "مسؤول أكاديمي");
    document.body.classList.toggle("role-editor", !!session && session.role === "محرر محتوى");

    // نحتفظ بأي محتوى وضعته الصفحة داخل app-shell قبل الحقن (نادر الاستخدام حالياً)
    const preExisting = document.createDocumentFragment();
    while (shell.firstChild) preExisting.appendChild(shell.firstChild);

    shell.outerHTML = buildShellHtml(activeKey, session);

    const pageContent = document.getElementById("pageContent");
    pageContent.appendChild(preExisting);

    initRoleGuardLinks();
    initMobileToggle();
    initTopbarScroll();
    initLogout();

    // ✅ إصلاح وميض/تأخر الشريط الجانبي — الشريط والمحتوى مخفيان افتراضياً
    // (راجع admin.css: html:not(.shell-ready)) حتى لا تظهر حالة "ناقصة"
    // للحظة على شبكة بطيئة. لا نكشفهما إلا بعد اكتمال البناء + جاهزية
    // الخطوط (فأيقونات Font Awesome لا تظهر كمربعات فارغة ثم تتبدّل).
    // مهلة أمان قصيرة حتى لا يتعطّل الظهور لو تأخر تحميل الخطوط كثيراً.
    revealShell();

    // كل صفحة تستمع لهذا الحدث بدل الاعتماد على ترتيب تحميل السكربتات
    document.dispatchEvent(new CustomEvent("shell:ready"));
  }

  function revealShell() {
    const reveal = () => {
      requestAnimationFrame(() => document.documentElement.classList.add("shell-ready"));
    };
    if (document.fonts && document.fonts.ready) {
      const safety = setTimeout(reveal, 400);
      document.fonts.ready.then(() => { clearTimeout(safety); reveal(); }).catch(reveal);
    } else {
      reveal();
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    try {
      const notice = sessionStorage.getItem("assoc_denied_notice");
      if (notice) {
        sessionStorage.removeItem("assoc_denied_notice");
        setTimeout(() => { if (typeof Feedback !== "undefined" && Feedback.info) Feedback.info(notice, 6500); }, 180);
      }
    } catch (e) {}
    mount();
  });

  // ✅ إصلاح بقاء الشريط الجانبي مفتوحاً بعد "تراجع" المتصفح
  // ------------------------------------------------------------
  // عند الرجوع بالمتصفح، بعض المتصفحات (خصوصاً على الجوال) تستعيد
  // الصفحة من ذاكرة bfcache بحالتها القديمة كما هي (DOM كاملاً) بدل
  // إعادة تحميلها من جديد — فلو كان المستخدم قد فتح القائمة الجانبية
  // قبل الانتقال لصفحة أخرى عبرها، ثم رجع، تظهر الصفحة السابقة والقائمة
  // ما زالت مفتوحة فوقها. نستمع لحدث pageshow ونتأكد من إغلاق القائمة
  // كل مرة تُستعاد الصفحة من هذه الذاكرة (event.persisted === true).
  window.addEventListener("pageshow", function (event) {
    if (!event.persisted) return;
    const sidebar = document.getElementById("sidebar");
    const overlay = document.getElementById("appOverlay");
    if (sidebar) sidebar.classList.remove("is-open");
    if (overlay) overlay.classList.remove("is-visible");
  });
})();
