/* ============================================================
   مكوّن نافذة منبثقة عام (Modal) — يُستخدم لأي نموذج إضافة/تعديل
   أو تأكيد حذف في أي صفحة إدارة، دون تكرار نفس كود الفتح/الإغلاق.
   ============================================================ */
const Modal = (function () {

  let overlayEl = null;

  function ensureOverlay() {
    if (overlayEl) return overlayEl;
    overlayEl = document.createElement("div");
    overlayEl.className = "modal-overlay";
    overlayEl.innerHTML = `
      <div class="modal">
        <div class="modal-header">
          <h3 id="modalTitle"></h3>
          <button class="icon-btn" id="modalCloseBtn" type="button" aria-label="إغلاق"><i class="fa-solid fa-xmark"></i></button>
        </div>
        <div class="modal-body" id="modalBody"></div>
        <div class="modal-footer" id="modalFooter"></div>
      </div>
    `;
    document.body.appendChild(overlayEl);
    overlayEl.addEventListener("click", (e) => { if (e.target === overlayEl) close(); });
    overlayEl.querySelector("#modalCloseBtn").addEventListener("click", close);
    return overlayEl;
  }

  /**
   * يفتح نافذة عامة.
   * @param {Object} opts
   * @param {string} opts.title
   * @param {string} opts.bodyHtml
   * @param {Array<{label:string, className:string, onClick:Function}>} [opts.buttons]
   */
  function open(opts) {
    const el = ensureOverlay();
    el.querySelector("#modalTitle").textContent = opts.title || "";
    const body = el.querySelector("#modalBody");
    body.replaceChildren();
    if (opts.bodyHtml) {
      const tpl = document.createElement("template");
      tpl.innerHTML = opts.bodyHtml;
      body.appendChild(tpl.content.cloneNode(true));
    }

    const footer = el.querySelector("#modalFooter");
    footer.innerHTML = "";
    (opts.buttons || []).forEach(btn => {
      const b = document.createElement("button");
      b.type = "button";
      b.className = "btn " + (btn.className || "btn-secondary");
      b.textContent = btn.label;
      // ⚠️ نمرّر عنصر الزر نفسه لـ onClick — تحتاجه الصفحات لربط
      // العملية بـ Feedback.busy(btn, ...) وإظهار مؤشر "قيد التنفيذ"
      // عليه مباشرة بدل أي تصرف صامت.
      b.addEventListener("click", () => btn.onClick && btn.onClick(b));
      footer.appendChild(b);
    });

    el.classList.add("is-open");
    document.body.classList.add("modal-open");
    setTimeout(() => { const first = el.querySelector("input,select,textarea,button:not(#modalCloseBtn)"); if (first) first.focus(); }, 0);
    return el;
  }

  function close() {
    if (overlayEl) { overlayEl.classList.remove("is-open"); document.body.classList.remove("modal-open"); }
  }

  /** نافذة تأكيد بسيطة تُعيد Promise<boolean> بدل confirm() الافتراضية للمتصفح */
  function confirmDialog(message, confirmLabel) {
    return new Promise(resolve => {
      const el = ensureOverlay();
      el.querySelector("#modalTitle").textContent = "تأكيد";
      const body = el.querySelector("#modalBody");
      body.replaceChildren();
      const p = document.createElement("p");
      p.style.cssText = "color:var(--ink-700);font-size:.9rem;line-height:1.8";
      p.textContent = message == null ? "" : String(message);
      body.appendChild(p);
      const footer = el.querySelector("#modalFooter");
      footer.replaceChildren();
      [
        { label: "إلغاء", className: "btn-secondary", onClick: () => { close(); resolve(false); } },
        { label: confirmLabel || "تأكيد", className: "btn-danger", onClick: () => { close(); resolve(true); } }
      ].forEach(btn => {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "btn " + btn.className;
        b.textContent = btn.label;
        b.addEventListener("click", () => btn.onClick(b));
        footer.appendChild(b);
      });
      el.classList.add("is-open");
      document.body.classList.add("modal-open");
      setTimeout(() => { const first = el.querySelector("button:not(#modalCloseBtn)"); if (first) first.focus(); }, 0);
    });
  }

  return { open, close, confirmDialog };
})();
