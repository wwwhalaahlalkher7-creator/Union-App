/* ============================================================
   يُستخدم في login.html فقط (عكس js/auth.js): إن وُجدت جلسة
   صالحة بالفعل، لا داعي لإظهار نموذج الدخول من جديد.
   ============================================================ */
(function () {
  try {
    const s = JSON.parse(localStorage.getItem("assoc_admin_session"));
    if (s && s.expiresAt > Date.now()) location.replace("index.html");
  } catch (e) { /* لا شيء محفوظ أو تالف — تابع لعرض نموذج الدخول */ }
})();
