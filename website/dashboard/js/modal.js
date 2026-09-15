/* ============================================================
   Modal — نافذة موحّدة وآمنة للوحة التحكم
   - دعم ESC وTab trap
   - إعادة التركيز إلى الزر الذي فتح النافذة
   - دعم لوحة المفاتيح/الجوال والـvisual viewport
   - منع قفز الصفحة عند فتح/إغلاق النافذة
   ============================================================ */
const Modal = (function () {
  let overlayEl = null;
  let restoreFocusEl = null;
  let keydownBound = false;

  function ensureOverlay() {
    if (overlayEl) return overlayEl;

    overlayEl = document.createElement("div");
    overlayEl.className = "modal-overlay";
    overlayEl.setAttribute("aria-hidden", "true");
    overlayEl.innerHTML = `
      <div class="modal" role="dialog" aria-modal="true" aria-labelledby="modalTitle" tabindex="-1">
        <div class="modal-header">
          <h3 id="modalTitle"></h3>
          <button class="icon-btn modal-close-btn" id="modalCloseBtn" type="button" aria-label="إغلاق">
            <i class="fa-solid fa-xmark" aria-hidden="true"></i>
          </button>
        </div>
        <div class="modal-body" id="modalBody"></div>
        <div class="modal-footer" id="modalFooter"></div>
      </div>
    `;

    document.body.appendChild(overlayEl);
    overlayEl.addEventListener("click", e => {
      if (e.target === overlayEl) close();
    });
    overlayEl.querySelector("#modalCloseBtn").addEventListener("click", close);

    if (!keydownBound) {
      keydownBound = true;
      document.addEventListener("keydown", handleKeydown);
    }

    if (window.visualViewport) {
      const syncViewport = () => {
        document.documentElement.style.setProperty("--modal-vvh", `${window.visualViewport.height}px`);
        if (overlayEl.classList.contains("is-open")) {
          requestAnimationFrame(() => {
            const active = document.activeElement;
            if (active && overlayEl.contains(active) && /^(INPUT|SELECT|TEXTAREA)$/.test(active.tagName)) {
              active.scrollIntoView({ block: "center", inline: "nearest", behavior: "auto" });
            }
          });
        }
      };
      window.visualViewport.addEventListener("resize", syncViewport);
      window.visualViewport.addEventListener("scroll", syncViewport);
      syncViewport();
    }

    return overlayEl;
  }

  function focusables() {
    if (!overlayEl) return [];
    return [...overlayEl.querySelectorAll(
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'
    )].filter(el => el.offsetParent !== null);
  }

  function handleKeydown(event) {
    if (!overlayEl || !overlayEl.classList.contains("is-open")) return;

    if (event.key === "Escape") {
      event.preventDefault();
      close();
      return;
    }

    if (event.key !== "Tab") return;
    const items = focusables();
    if (!items.length) {
      event.preventDefault();
      overlayEl.querySelector(".modal").focus();
      return;
    }

    const first = items[0];
    const last = items[items.length - 1];

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function mountBody(html) {
    const body = overlayEl.querySelector("#modalBody");
    body.replaceChildren();
    if (!html) return;
    const tpl = document.createElement("template");
    tpl.innerHTML = html;
    body.appendChild(tpl.content.cloneNode(true));
  }

  function mountButtons(buttons) {
    const footer = overlayEl.querySelector("#modalFooter");
    footer.replaceChildren();

    (buttons || []).forEach(config => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "btn " + (config.className || "btn-secondary");
      button.textContent = config.label;
      button.addEventListener("click", () => config.onClick && config.onClick(button));
      footer.appendChild(button);
    });
  }

  function open(opts = {}) {
    const el = ensureOverlay();
    restoreFocusEl = document.activeElement instanceof HTMLElement ? document.activeElement : null;

    el.querySelector("#modalTitle").textContent = opts.title || "";
    mountBody(opts.bodyHtml);
    mountButtons(opts.buttons);

    el.classList.add("is-open");
    el.setAttribute("aria-hidden", "false");
    document.body.classList.add("modal-open");

    const modal = el.querySelector(".modal");
    requestAnimationFrame(() => {
      const first = focusables()[0];
      (first || modal).focus();
      const active = document.activeElement;
      if (active && /^(INPUT|SELECT|TEXTAREA)$/.test(active.tagName)) {
        active.scrollIntoView({ block: "center", inline: "nearest", behavior: "auto" });
      }
    });

    return el;
  }

  function close() {
    if (!overlayEl || !overlayEl.classList.contains("is-open")) return;

    overlayEl.classList.remove("is-open");
    overlayEl.setAttribute("aria-hidden", "true");
    document.body.classList.remove("modal-open");

    const target = restoreFocusEl;
    restoreFocusEl = null;
    if (target && document.contains(target) && !target.disabled) {
      requestAnimationFrame(() => target.focus());
    }
  }

  function confirmDialog(message, confirmLabel) {
    return new Promise(resolve => {
      const el = ensureOverlay();
      restoreFocusEl = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      el.querySelector("#modalTitle").textContent = "تأكيد";

      const body = el.querySelector("#modalBody");
      body.replaceChildren();
      const p = document.createElement("p");
      p.className = "modal-confirm-message";
      p.textContent = message == null ? "" : String(message);
      body.appendChild(p);

      mountButtons([
        { label: "إلغاء", className: "btn-secondary", onClick: () => { close(); resolve(false); } },
        { label: confirmLabel || "تأكيد", className: "btn-danger", onClick: () => { close(); resolve(true); } }
      ]);

      el.classList.add("is-open");
      el.setAttribute("aria-hidden", "false");
      document.body.classList.add("modal-open");

      requestAnimationFrame(() => {
        const items = focusables();
        if (items[0]) items[0].focus();
      });
    });
  }

  return Object.freeze({ open, close, confirmDialog });
})();
