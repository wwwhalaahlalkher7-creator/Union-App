/* ============================================================
   نظام تغذية راجعة موحّد — Feedback.js
   ------------------------------------------------------------
   ⚠️ قاعدة صارمة تطبَّق عبر كل صفحات اللوحة: ممنوع أي تصرف صامت.
   كل عملية شبكة (حفظ / تعديل / حذف / تحميل قائمة) يجب أن تمر عبر
   Feedback.busy() أو Feedback.loadInto()/loadIntoTable()، وليس عبر
   `await Adapter.xxx()` مباشرة بلا غلاف. هذا يضمن:

     1. مؤشر "قيد التنفيذ" يظهر فوراً على العنصر المسبِّب (زر/جدول) —
        حتى لو استجاب الخادم خلال أجزاء من الثانية، يبقى المؤشر ظاهراً
        لمدة MIN_VISIBLE_MS على الأقل حتى لا يومض بسرعة لا تُرى. وإن
        تأخر الخادم أو كانت الشبكة بطيئة، يبقى المؤشر ظاهراً طوال
        فترة الانتظار — لا فراغ صامت أبداً.
     2. عند النجاح: رسالة Toast تخبر المستخدم صراحة أن الأمر تم.
     3. عند الفشل: رسالة Toast خطأ إجبارية — لا استثناء يُبتلع بصمت.
     4. الواجهة لا تتغيّر (إغلاق نافذة، تحديث قائمة) إلا بعد نجاح
        الطلب فعلياً — لا تحديث تفاؤلي (optimistic) يُظهر نتيجة
        التعديل قبل تأكيد الخادم.

   يعتمد على Utils (utils.js) لتنقية أي نص خطأ قبل إدراجه في HTML —
   يجب تحميل utils.js قبل هذا الملف.
   ============================================================ */
const Feedback = (function () {

  const MIN_VISIBLE_MS = 350; // أقل مدة ظهور لمؤشر "قيد التنفيذ" — يمنع الوميض غير المرئي

  /* ---------------------------------------------------------
     1) Toast — إشعارات عابرة غير حاجبة
     --------------------------------------------------------- */
  let stackEl = null;
  function ensureStack() {
    if (stackEl) return stackEl;
    stackEl = document.createElement("div");
    stackEl.className = "toast-stack";
    document.body.appendChild(stackEl);
    return stackEl;
  }

  function toast(message, type, timeoutMs) {
    const stack = ensureStack();
    const el = document.createElement("div");
    el.className = "toast toast--" + type;
    const icon = type === "success" ? "fa-circle-check"
               : type === "error"   ? "fa-circle-exclamation"
               : "fa-circle-info";
    el.innerHTML =
      '<i class="fa-solid ' + icon + '"></i>' +
      '<span class="toast-msg"></span>' +
      '<button type="button" class="toast-close" aria-label="إغلاق"><i class="fa-solid fa-xmark"></i></button>';
    el.querySelector(".toast-msg").textContent = message; // textContent — لا حاجة لتنقية، لا خطر HTML
    stack.appendChild(el);

    requestAnimationFrame(() => el.classList.add("is-visible"));

    let dismissed = false;
    function remove() {
      if (dismissed) return;
      dismissed = true;
      el.classList.remove("is-visible");
      setTimeout(() => el.remove(), 220);
    }
    el.querySelector(".toast-close").addEventListener("click", remove);
    if (timeoutMs !== 0) setTimeout(remove, timeoutMs || (type === "error" ? 6000 : 3500));
    return { el, remove };
  }

  const success = (msg) => toast(msg, "success");
  const error   = (msg) => toast(msg, "error", 6000); // أطول ظهوراً — رسائل الخطأ يجب أن تُقرأ فعلاً
  const info    = (msg) => toast(msg, "info");

  function errorMessageOf(err) {
    return (err && err.message) ? err.message : "حدث خطأ غير متوقع، حاول مرة أخرى";
  }

  /* ---------------------------------------------------------
     2) Feedback.busy — يلفّ عملية شبكة مرتبطة بزر واحد
     --------------------------------------------------------- */
  /**
   * @param {HTMLElement} btn - الزر المسبِّب للعملية
   * @param {Function} fn - async function تنفّذ الطلب الفعلي
   * @param {Object} [opts]
   * @param {string} [opts.busyLabel] - نص يظهر بجانب مؤشر الدوران أثناء التنفيذ (فارغ = أيقونة فقط، مناسب لأزرار الأيقونات)
   * @param {string} [opts.successMessage] - إن حُدِّدت تظهر Toast نجاح بهذا النص
   * @param {string} [opts.errorPrefix] - يُضاف قبل رسالة الخطأ الفعلية في Toast الفشل
   * @returns {Promise} نتيجة fn — يُعاد رمي الخطأ للمستدعي عند الفشل كي يقرر ماذا يفعل (مثلاً: عدم إغلاق نافذة منبثقة)
   */
  async function busy(btn, fn, opts) {
    opts = opts || {};
    const originalHtml = btn.innerHTML;
    const wasDisabled = btn.disabled;

    btn.disabled = true;
    btn.classList.add("is-busy");
    btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>' +
      (opts.busyLabel ? ' ' + Utils.escapeHtml(opts.busyLabel) : "");

    const startedAt = Date.now();
    async function waitMinVisible() {
      const elapsed = Date.now() - startedAt;
      if (elapsed < MIN_VISIBLE_MS) await new Promise(r => setTimeout(r, MIN_VISIBLE_MS - elapsed));
    }

    try {
      const result = await fn();
      await waitMinVisible();
      if (opts.successMessage) success(opts.successMessage);
      return result;
    } catch (err) {
      await waitMinVisible();
      error((opts.errorPrefix ? opts.errorPrefix + ": " : "") + errorMessageOf(err));
      throw err;
    } finally {
      btn.disabled = wasDisabled;
      btn.classList.remove("is-busy");
      btn.innerHTML = originalHtml;
    }
  }

  /* ---------------------------------------------------------
     3) Feedback.loadInto / loadIntoTable — تحميل بيانات صفحة كاملة
     --------------------------------------------------------- */
  function loadingMarkup(label) {
    return '<div class="empty-state"><i class="fa-solid fa-spinner fa-spin"></i>' + Utils.escapeHtml(label) + '</div>';
  }
  function errorMarkup(label, retryId) {
    return '<div class="empty-state is-error-state">' +
      '<i class="fa-solid fa-triangle-exclamation"></i>' + Utils.escapeHtml(label) +
      '<button type="button" class="btn btn-secondary" id="' + retryId + '" style="margin-top:12px">' +
      '<i class="fa-solid fa-rotate-right"></i> إعادة المحاولة</button></div>';
  }

  /**
   * @param {HTMLElement} containerEl - عنصر عادي (div) يُستبدل محتواه بالكامل
   */
  async function loadInto(containerEl, fn, onSuccess, opts) {
    opts = opts || {};
    const retryId = "retry-" + Math.random().toString(36).slice(2);
    containerEl.innerHTML = loadingMarkup(opts.loadingLabel || "جارٍ التحميل...");
    try {
      const data = await fn();
      onSuccess(data);
    } catch (err) {
      containerEl.innerHTML = errorMarkup(
        (opts.errorPrefix || "تعذّر التحميل") + ": " + errorMessageOf(err), retryId
      );
      containerEl.querySelector("#" + retryId)
        .addEventListener("click", () => loadInto(containerEl, fn, onSuccess, opts));
      error((opts.errorPrefix || "تعذّر التحميل") + ": " + errorMessageOf(err));
    }
  }

  /**
   * نفس loadInto لكن لعنصر <tbody> — يبني الحالة داخل <tr><td colspan>
   * لأن أي عنصر غير <tr>/<td> غير صالح داخل <tbody> مباشرة.
   * @param {HTMLElement} tbodyEl
   * @param {number} colspan
   */
  async function loadIntoTable(tbodyEl, colspan, fn, onSuccess, opts) {
    opts = opts || {};
    const retryId = "retry-" + Math.random().toString(36).slice(2);
    tbodyEl.innerHTML = '<tr><td colspan="' + colspan + '">' + loadingMarkup(opts.loadingLabel || "جارٍ التحميل...") + '</td></tr>';
    try {
      const data = await fn();
      onSuccess(data);
    } catch (err) {
      tbodyEl.innerHTML = '<tr><td colspan="' + colspan + '">' +
        errorMarkup((opts.errorPrefix || "تعذّر التحميل") + ": " + errorMessageOf(err), retryId) +
        '</td></tr>';
      tbodyEl.querySelector("#" + retryId)
        .addEventListener("click", () => loadIntoTable(tbodyEl, colspan, fn, onSuccess, opts));
      error((opts.errorPrefix || "تعذّر التحميل") + ": " + errorMessageOf(err));
    }
  }

  return { success, error, info, busy, loadInto, loadIntoTable };
})();
