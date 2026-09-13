/* ============================================================
   Ad Manager — محرك الإعلانات لصفحات الموقع العام (ad-manager.js)
   Phase 2: Ad Manager + Providers
   ✅ Phase 5 — يرسل الآن placement/provider مع كل نداء تتبّع (لشيت
   AdEvents الجديد في Airtable.js، أساس تبويب "التحليلات" في اللوحة)،
   ويتتبّع ظهور كل المزوّدين لا المباشر فقط (راجع trackAdEvent_ وتعديل
   tryProviderChain_ أدناه). لا تغيير على منطق اختيار/عرض الإعلانات نفسه.
   ------------------------------------------------------------
   الاستخدام في أي صفحة عامة:
     <div data-ad-placement="homepage_top"></div>
     ...
     <script src="ad-manager.js"></script>
   لا حاجة لاستدعاء أي شيء يدويًا — يعرض تلقائيًا كل حاوية
   [data-ad-placement] موجودة في الصفحة عند تحميل DOM (Phase 3
   سيضيف هذه الحاويات + السكربت لصفحات الموقع الفعلية).

   المبدأ: الصفحة لا تعرف شيئًا عن AdSense/Adsterra/Monetag —
   تستدعي فقط Placement بالاسم، وAdManager هو من يقرر المزوّد
   (حسب إعدادات اللوحة) مع نظام Fallback وTest Mode.

   ⚠️ صيغ سكربتات AdSense/Adsterra/Monetag أدناه هي الصيغ الشائعة
   المعروفة لكل شبكة، لكن كل شبكة قد تُحدّث كود التضمين من طرفها —
   تحقق من الكود الفعلي في لوحة كل شبكة عند التفعيل الحقيقي (خصوصًا
   Monetag الذي يوفر أنواع تكامل مختلفة). التعديل محصور في طبقة
   AdProviders_ أدناه فقط، بلا أي أثر على بقية الملف أو على الصفحات.
   ============================================================ */
(function (global) {
  'use strict';

  // 👇 نفس رابط api.content.baseUrl الموجود في admin/config.js — نفس
  // مشروع Airtable.js يخدم الآن action=adSettings وaction=impression/click
  // بالإضافة لدوره الأصلي (أخبار/إنجازات/أنشطة/إعلانات مباشرة).
  var AD_API_URL = "https://script.google.com/macros/s/AKfycbwIZBuPEaZ8TD08HoaSPIC_WfP8hhhkGkKtHk4bwZAkG7x_cxABToy8zdw9Kc4CH6yOUw/exec";

  var SETTINGS_CACHE_KEY = "assoc_ad_settings_v1";
  var SETTINGS_CACHE_TTL_MS = 5 * 60 * 1000;   // يطابق كاش الخادم (5 دقائق)
  var ADS_CACHE_KEY = "assoc_direct_ads_v1";
  var ADS_CACHE_TTL_MS = 5 * 60 * 1000;

  var loadedScripts_ = {}; // منع تحميل سكربت نفس المزوّد أكثر من مرة في نفس الصفحة

  /* ------------------------------------------------------------
     0) أدوات عامة صغيرة
     ------------------------------------------------------------ */
  function readCache_(key, ttlMs) {
    try {
      var raw = sessionStorage.getItem(key);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (!parsed || !parsed.t || (Date.now() - parsed.t) > ttlMs) return null;
      return parsed.v;
    } catch (e) { return null; } // خصوصية المتصفح قد تمنع sessionStorage — لا كسر
  }
  function writeCache_(key, value) {
    try { sessionStorage.setItem(key, JSON.stringify({ t: Date.now(), v: value })); }
    catch (e) { /* تجاهل بصمت */ }
  }
  function fetchJson_(url) {
    return fetch(url).then(function (res) { return res.json(); });
  }
  /**
   * ✅ جديد — يطبّق فعليًا حقل minIntervalMinutes (كان مخزَّناً/قابلاً
   * للتعديل من اللوحة منذ Phase 4 بلا أي تأثير حقيقي). نخزّن آخر وقت
   * "عرض فعلي ناجح" لكل Placement في localStorage (يدوم عبر الجلسات/
   * التبويبات لنفس المتصفح — هذا حد أدنى بين مرات العرض للزائر نفسه
   * على مهلة، لا لكل تحميل صفحة فقط، فـsessionStorage غير مناسب هنا).
   */
  var AD_LAST_SHOWN_PREFIX_ = "assoc_ad_last_shown_";
  function getLastShown_(placementKey) {
    try {
      var v = localStorage.getItem(AD_LAST_SHOWN_PREFIX_ + placementKey);
      return v ? parseInt(v, 10) : 0;
    } catch (e) { return 0; } // خصوصية المتصفح قد تمنع localStorage — لا كسر، فقط لا حد أدنى فعّال
  }
  function setLastShown_(placementKey) {
    try { localStorage.setItem(AD_LAST_SHOWN_PREFIX_ + placementKey, String(Date.now())); }
    catch (e) { /* تجاهل بصمت */ }
  }
  function escapeHtml_(str) {
    return String(str == null ? "" : str).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  /**
   * ✅ جديد Phase 6 (Security hardening) — يقبل فقط روابط http(s) قبل
   * استخدامها كـhref/src على الموقع العام. حماية دفاعية إضافية (defense
   * in depth): هذه الحقول تُدخَل أصلاً من لوحة تحكم محمية (محرر/مدير
   * فقط)، لكن رفض أي مخطط آخر (javascript:, data:, vbscript:...) هنا
   * أيضًا يمنع أي رابط خاطئ أو مخترَق من التنفيذ في متصفح كل زائر للموقع
   * العام، بلا أي تغيير على الروابط الصحيحة (http/https تمر كما هي).
   * @param {string} url
   * @return {?string} الرابط نفسه إن كان آمنًا، أو null لرفضه
   */
  function safeHttpUrl_(url) {
    if (typeof url !== "string") return null;
    var trimmed = url.trim();
    if (/^https?:\/\//i.test(trimmed)) return trimmed;
    return null;
  }

  /* ------------------------------------------------------------
     1) جلب إعدادات مدير الإعلانات (Placements + Providers) — مرة
        واحدة لكل تحميل صفحة، بكاش sessionStorage قصير فوق كاش
        الخادم (فيصبح الاستدعاء فوريًا للزيارة الثانية بنفس الجلسة).
     ------------------------------------------------------------ */
  var settingsPromise_ = null;
  function getSettings_() {
    if (settingsPromise_) return settingsPromise_;
    var cached = readCache_(SETTINGS_CACHE_KEY, SETTINGS_CACHE_TTL_MS);
    if (cached) { settingsPromise_ = Promise.resolve(cached); return settingsPromise_; }

    settingsPromise_ = fetchJson_(AD_API_URL + "?" + new URLSearchParams({ action: "adSettings" }))
      .then(function (data) {
        var settings = (data && data.success && data.settings) ? data.settings : null;
        if (settings) writeCache_(SETTINGS_CACHE_KEY, settings);
        return settings;
      })
      .catch(function () { return null; }); // فشل الشبكة = لا إعلانات في هذه الزيارة، بلا كسر للصفحة
    return settingsPromise_;
  }

  /* ------------------------------------------------------------
     2) جلب الإعلانات المباشرة النشطة (لمزوّد "direct" فقط) — من
        نفس مسار المحتوى الحالي (?type=ads)، بلا أي endpoint جديد.
     ------------------------------------------------------------ */
  var directAdsPromise_ = null;
  function getDirectAds_() {
    if (directAdsPromise_) return directAdsPromise_;
    var cached = readCache_(ADS_CACHE_KEY, ADS_CACHE_TTL_MS);
    if (cached) { directAdsPromise_ = Promise.resolve(cached); return directAdsPromise_; }

    directAdsPromise_ = fetchJson_(AD_API_URL + "?" + new URLSearchParams({ type: "ads" }))
      .then(function (data) {
        var records = (data && data.records) ? data.records : [];
        writeCache_(ADS_CACHE_KEY, records);
        return records;
      })
      .catch(function () { return []; });
    return directAdsPromise_;
  }

  function isAdActiveNow_(fields) {
    if (!fields.Active) return false;
    var now = new Date();
    if (fields.StartDate && new Date(fields.StartDate) > now) return false;
    if (fields.EndDate && new Date(fields.EndDate) < now) return false;
    return true;
  }

  /**
   * يختار أفضل إعلان مباشر لموضع معيّن حسب الأولوية (Priority الأصغر أولاً).
   * ⚠️ إعلانات قديمة بلا حقل Placement (من قبل Phase 1) تُعتبر صالحة لأي
   * موضع مؤقتًا — حتى يُحدَّد لها Placement صريح من اللوحة (Phase 4).
   */
  function pickDirectAdForPlacement_(records, placementKey) {
    var candidates = records.filter(function (r) {
      var f = r.fields || {};
      return isAdActiveNow_(f) && (f.Placement === placementKey || !f.Placement);
    }).sort(function (a, b) {
      var pa = (a.fields.Priority != null) ? a.fields.Priority : 999;
      var pb = (b.fields.Priority != null) ? b.fields.Priority : 999;
      return pa - pb;
    });
    return candidates[0] || null;
  }

  function trackDirectAdEvent_(id, kind, placementKey) {
    var action = (kind === "click") ? "click" : "impression";
    // نفس مسار doGet?action=impression|click&id=... الموجود مسبقًا في Airtable.js
    // ✅ Phase 5 — placement/provider يُرسَلان الآن أيضًا (يُسجَّلان في شيت
    // AdEvents الجديد لأغراض التحليلات بالفترة)، بلا أي تغيير على سلوك
    // عدّاد Airtable القديم لكل إعلان.
    fetch(AD_API_URL + "?" + new URLSearchParams({ action: action, id: id, placement: placementKey || "", provider: "direct" })).catch(function () {});
  }

  /**
   * ✅ جديد Phase 5 — تتبّع ظهور من مزوّد خارجي (AdSense/Adsterra/
   * Monetag/Custom) لا يملك سجل إعلان في Airtable — بلا id، فقط
   * Placement/Provider، يُسجَّل في شيت AdEvents فقط (راجع
   * _handleAdCounterRoute_ في Airtable.js). النقر لا يُتتبَّع لهذه
   * الشبكات (تديره كل شبكة بنفسها داخل iframe خاص بها).
   */
  function trackAdEvent_(placementKey, providerKey) {
    fetch(AD_API_URL + "?" + new URLSearchParams({ action: "impression", placement: placementKey || "", provider: providerKey || "" })).catch(function () {});
  }

  /* ------------------------------------------------------------
     3) Ad Provider Layer — كل مزوّد يعرّف render(container, placementCfg,
        providerCfg, onResult, ctx). onResult(true) = نجح العرض،
        onResult(false) = لا يوجد إعلان متاح → ينتقل AdManager تلقائيًا
        لمزوّد الـFallback. إضافة مزوّد جديد = كائن جديد هنا فقط، بلا
        أي تعديل على render()/tryProviderChain_() أو على صفحات الموقع.
     ------------------------------------------------------------ */
  var AdProviders_ = {};

  function loadScriptOnce_(src, attrs) {
    if (loadedScripts_[src]) return loadedScripts_[src];
    var p = new Promise(function (resolve, reject) {
      var s = document.createElement("script");
      s.src = src;
      s.async = true;
      if (attrs) Object.keys(attrs).forEach(function (k) { s.setAttribute(k, attrs[k]); });
      s.onload = function () { resolve(); };
      s.onerror = function () { reject(new Error("تعذّر تحميل سكربت المزوّد: " + src)); };
      document.head.appendChild(s);
    });
    loadedScripts_[src] = p;
    return p;
  }

  /** Google AdSense — يتطلب Publisher ID (على مستوى المزوّد) + Ad Slot (على مستوى الموضع) */
  AdProviders_.adsense = {
    render: function (container, placementCfg, providerCfg, onResult) {
      if (!providerCfg || !providerCfg.publisherId || !placementCfg.adUnitId) { onResult(false); return; }
      loadScriptOnce_(
        "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=" + encodeURIComponent(providerCfg.publisherId),
        { crossorigin: "anonymous" }
      ).then(function () {
        var ins = document.createElement("ins");
        ins.className = "adsbygoogle";
        ins.style.display = "block";
        ins.setAttribute("data-ad-client", providerCfg.publisherId);
        ins.setAttribute("data-ad-slot", placementCfg.adUnitId);
        ins.setAttribute("data-ad-format", "auto");
        ins.setAttribute("data-full-width-responsive", "true");
        container.appendChild(ins);
        (global.adsbygoogle = global.adsbygoogle || []).push({});
        onResult(true); // ✅ AdSense لا يبلّغنا فعليًا بنجاح التعبئة؛ نعتبر حقن السكربت نجاحًا
      }).catch(function () { onResult(false); });
    }
  };

  /** Adsterra — بانر Zone ID (صيغة atOptions + invoke.js الشائعة للبانرات) */
  AdProviders_.adsterra = {
    render: function (container, placementCfg, providerCfg, onResult) {
      if (!placementCfg.adUnitId) { onResult(false); return; }
      var zoneId = placementCfg.adUnitId.replace(/[^a-zA-Z0-9]/g, "");
      var configScript = document.createElement("script");
      configScript.type = "text/javascript";
      configScript.text = "atOptions = { key: '" + zoneId + "', format: 'iframe', height: 90, width: 728, params: {} };";
      container.appendChild(configScript);
      loadScriptOnce_("https://www.highperformanceformat.com/" + encodeURIComponent(zoneId) + "/invoke.js")
        .then(function () { onResult(true); })
        .catch(function () { onResult(false); });
    }
  };

  /** Monetag — تحميل tag.min.js الخاص بالـZone؛ الشبكة تدير عرضها بنفسها بعد التحميل */
  AdProviders_.monetag = {
    render: function (container, placementCfg, providerCfg, onResult) {
      if (!placementCfg.adUnitId) { onResult(false); return; }
      var zoneId = placementCfg.adUnitId.replace(/[^a-zA-Z0-9]/g, "");
      loadScriptOnce_("https://" + zoneId + ".highrevenuenetwork.com/tag.min.js")
        .then(function () { onResult(true); })
        .catch(function () { onResult(false); });
    }
  };

  /** شبكة مخصّصة — رابط سكربت كامل من إعدادات المزوّد في اللوحة */
  AdProviders_.custom = {
    render: function (container, placementCfg, providerCfg, onResult) {
      var scriptUrl = providerCfg && safeHttpUrl_(providerCfg.scriptUrl); // ✅ Phase 6
      if (!scriptUrl) { onResult(false); return; }
      loadScriptOnce_(scriptUrl)
        .then(function () { onResult(true); })
        .catch(function () { onResult(false); });
    }
  };

  /** إعلان مباشر — من جدول Ads نفسه (Airtable)، بصورة/عنوان/رابط + تتبّع Impression/Click حقيقي */
  AdProviders_.direct = {
    render: function (container, placementCfg, providerCfg, onResult, ctx) {
      getDirectAds_().then(function (records) {
        var record = pickDirectAdForPlacement_(records, ctx.placementKey);
        if (!record) { onResult(false); return; }
        var f = record.fields;

        var a = document.createElement("a");
        a.href = safeHttpUrl_(f.LinkUrl) || "#"; // ✅ Phase 6 — يرفض أي مخطط غير http/https
        a.target = "_blank";
        a.rel = "noopener noreferrer sponsored";
        a.className = "ad-manager-direct-ad";
        a.style.display = "block";
        a.style.textDecoration = "none";

        if (f.Image && f.Image[0] && f.Image[0].url) {
          var img = document.createElement("img");
          img.src = f.Image[0].url;
          img.alt = f.Title || "إعلان";
          img.style.maxWidth = "100%";
          img.style.borderRadius = "8px";
          img.style.display = "block";
          a.appendChild(img);
        } else {
          a.textContent = f.Title || "إعلان";
        }

        a.addEventListener("click", function () { trackDirectAdEvent_(record.id, "click", ctx.placementKey); });
        container.appendChild(a);
        trackDirectAdEvent_(record.id, "impression", ctx.placementKey);
        onResult(true);
      }).catch(function () { onResult(false); });
    }
  };

  /* ------------------------------------------------------------
     4) Test Mode — Placeholder واضح بدل أي إعلان حقيقي
     ------------------------------------------------------------ */
  function renderTestPlaceholder_(container, placementKey, providerKey) {
    container.innerHTML = "";
    var box = document.createElement("div");
    box.setAttribute("style",
      "border:1px dashed #94a3b8;border-radius:8px;padding:14px;text-align:center;" +
      "font-family:sans-serif;font-size:13px;color:#64748b;background:#f8fafc;line-height:1.6;");
    box.innerHTML =
      "<div style=\"font-weight:700;margin-bottom:4px;\">[ AD PLACEHOLDER ]</div>" +
      "<div>Provider: " + escapeHtml_(providerKey || "—") + "</div>" +
      "<div>Placement: " + escapeHtml_(placementKey) + "</div>";
    container.appendChild(box);
  }

  /* ------------------------------------------------------------
     5) المحرك الأساسي: اختيار المزوّد + نظام Fallback
     ------------------------------------------------------------ */
  function tryProviderChain_(container, placementCfg, settings, providerChain, ctx) {
    if (!providerChain.length) return; // انتهت السلسلة بلا نتيجة → لا نعرض شيئًا (حسب المتطلبات)
    var providerKey = providerChain[0];
    var rest = providerChain.slice(1);
    var providerImpl = AdProviders_[providerKey];
    var providerCfg = settings.providers[providerKey];

    if (!providerImpl || !providerCfg || providerCfg.enabled === false) {
      tryProviderChain_(container, placementCfg, settings, rest, ctx);
      return;
    }

    providerImpl.render(container, placementCfg, providerCfg, function (success) {
      if (success) {
        setLastShown_(ctx.placementKey); // ✅ جديد — أساس تطبيق minIntervalMinutes للمرة القادمة
        // ✅ جديد Phase 5 — الإعلان المباشر يسجّل ظهوره بنفسه (يحتاج id
        // السجل الفعلي، راجع AdProviders_.direct أعلاه)؛ بقية المزوّدين
        // (لا سجل Airtable لهم) يُسجَّلون هنا مركزيًا بمجرد نجاح العرض.
        if (providerKey !== "direct") trackAdEvent_(ctx.placementKey, providerKey);
      } else {
        tryProviderChain_(container, placementCfg, settings, rest, ctx);
      }
    }, ctx);
  }

  /**
   * يعرض إعلانًا واحدًا في أول حاوية [data-ad-placement="placementKey"]
   * موجودة في الصفحة الحالية. يتجاهل بصمت إن لم توجد حاوية، أو كانت
   * الإعلانات معطّلة عمومًا، أو كان الموضع نفسه معطّلًا.
   * @param {string} placementKey
   */
  function render(placementKey) {
    var container = document.querySelector('[data-ad-placement="' + placementKey + '"]');
    if (!container) return;

    getSettings_().then(function (settings) {
      if (!settings || settings.global.adsEnabled === false) return;
      var placementCfg = settings.placements[placementKey];
      if (!placementCfg || placementCfg.enabled === false) return;

      var isTestMode = !!settings.global.testMode;
      if (isTestMode) {
        renderTestPlaceholder_(container, placementKey, placementCfg.provider);
        return; // Test Mode يظهر دائمًا فورًا بلا تأثير من الحد الأدنى (معاينة/فحص فقط، ليس عرضًا حقيقيًا)
      }

      // ✅ جديد — الحد الأدنى بين مرات العرض (minIntervalMinutes)، يُطبَّق
      // فقط على العرض الحقيقي (بعد Test Mode). 0 = بلا حد (السلوك الافتراضي
      // القديم، بلا أي تغيير لأي موضع لم يُضبَط له هذا الحقل صراحةً).
      var minInterval = Number(placementCfg.minIntervalMinutes) || 0;
      if (minInterval > 0) {
        var lastShown = getLastShown_(placementKey);
        if (lastShown && (Date.now() - lastShown) < minInterval * 60000) {
          return; // لم تمرّ المدة الكافية بعد منذ آخر عرض فعلي لهذا الموضع لهذا الزائر
        }
      }

      var chain = [placementCfg.provider, placementCfg.fallback].filter(Boolean);
      tryProviderChain_(container, placementCfg, settings, chain, { placementKey: placementKey });
    });
  }

  /** يعرض كل حاويات [data-ad-placement] الموجودة في الصفحة الحالية دفعة واحدة */
  function renderAll() {
    var containers = document.querySelectorAll("[data-ad-placement]");
    for (var i = 0; i < containers.length; i++) {
      render(containers[i].getAttribute("data-ad-placement"));
    }
  }

  global.AdManager = { render: render, renderAll: renderAll };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderAll);
  } else {
    renderAll();
  }
})(window);
