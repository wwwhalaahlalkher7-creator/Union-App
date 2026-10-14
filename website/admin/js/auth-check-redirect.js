/*
 * حارس صفحة الدخول: يعتمد على Auth باعتباره المصدر المركزي للجلسة
 * بدلاً من إعادة تحليل sessionStorage وتكرار منطق انتهاء الصلاحية.
 */
(function () {
  try {
    if (window.Auth && typeof window.Auth.get === "function" && window.Auth.get()) {
      location.replace("index.html");
    }
  } catch (e) { /* عند تعذر قراءة الجلسة، تابع عرض نموذج الدخول */ }
})();
