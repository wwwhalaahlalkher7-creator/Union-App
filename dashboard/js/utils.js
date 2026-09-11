/* ============================================================
   دوال تنسيق مشتركة — لتفادي تكرارها في كل صفحة لاحقة
   ============================================================ */
const Utils = (function () {

  /** تنسيق تاريخ ISO كـ "26 يوليو 2026" بأرقام لاتينية وتقويم ميلادي دائماً */
  function formatDate(isoDate) {
    const d = new Date(isoDate);
    return new Intl.DateTimeFormat("ar-u-nu-latn-ca-gregory", {
      day: "numeric", month: "long", year: "numeric"
    }).format(d);
  }

  /** تنسيق رقم بفواصل الآلاف بأرقام لاتينية (128 / 3,040) */
  function formatNumber(n) {
    return Number(n).toLocaleString("en-US");
  }

  /** تنقية أي نص قبل إدراجه داخل HTML — حماية أساسية عند التعامل مع بيانات حقيقية لاحقاً */
  function escapeHtml(str) {
    if (str === null || str === undefined) return "";
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  /**
   * ✅ جديد — يُحرِّك رقم بطاقة إحصائية تصاعدياً من قيمته الحالية (أو صفر
   * أول مرة) إلى القيمة الجديدة بدل استبداله فجأة، حتى عند التحديث
   * التلقائي الدوري (راجع index.html — setInterval لتحديث الإحصائيات).
   */
  function animateNumber(el, toValue, duration) {
    if (!el) return;
    const from = Number((el.dataset.rawValue || "0").replace(/,/g, "")) || 0;
    const to = Number(toValue) || 0;
    duration = duration || 700;
    if (from === to) { el.textContent = formatNumber(to); el.dataset.rawValue = to; return; }

    const start = performance.now();
    function step(now) {
      const progress = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - progress, 3); // ease-out
      const current = Math.round(from + (to - from) * eased);
      el.textContent = formatNumber(current);
      if (progress < 1) requestAnimationFrame(step);
      else el.dataset.rawValue = to;
    }
    requestAnimationFrame(step);
  }

  /**
   * ✅ جديد — زر "عين" لإظهار/إخفاء كلمة المرور، يُطبَّق تلقائياً على كل
   * حقل type="password" في أي صفحة (حالية أو تُضاف لاحقاً ديناميكياً —
   * مثل نموذج "إضافة مستخدم" في users.html أو أي Modal). لا حاجة لأي
   * صفحة أن تستدعي شيئاً بنفسها؛ يكفي تضمين utils.js كالعادة.
   */
  function enhancePasswordField_(input) {
    if (!input || input.dataset.pwEnhanced) return;
    input.dataset.pwEnhanced = "1";

    const wrap = document.createElement("div");
    wrap.className = "pw-toggle-wrap";
    input.parentNode.insertBefore(wrap, input);
    wrap.appendChild(input);

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "pw-toggle-btn";
    btn.setAttribute("aria-label", "إظهار كلمة المرور");
    btn.tabIndex = -1;
    btn.innerHTML = '<i class="fa-solid fa-eye"></i>';

    btn.addEventListener("click", () => {
      const showing = input.type === "text";
      input.type = showing ? "password" : "text";
      btn.innerHTML = showing ? '<i class="fa-solid fa-eye"></i>' : '<i class="fa-solid fa-eye-slash"></i>';
      btn.setAttribute("aria-label", showing ? "إظهار كلمة المرور" : "إخفاء كلمة المرور");
    });

    wrap.appendChild(btn);
  }

  function scanPasswordFields_(root) {
    (root || document).querySelectorAll('input[type="password"]').forEach(enhancePasswordField_);
  }

  // فحص فوري لأي حقول موجودة عند تحميل utils.js، + مراقبة أي إضافات
  // لاحقة (نماذج تُبنى ديناميكياً بعد shell:ready أو داخل Modal)
  scanPasswordFields_(document);
  new MutationObserver((mutations) => {
    mutations.forEach(m => {
      m.addedNodes.forEach(node => {
        if (node.nodeType !== 1) return;
        if (node.matches && node.matches('input[type="password"]')) enhancePasswordField_(node);
        else if (node.querySelectorAll) scanPasswordFields_(node);
      });
    });
  }).observe(document.documentElement, { childList: true, subtree: true });

  return { formatDate, formatNumber, escapeHtml, animateNumber };
})();
