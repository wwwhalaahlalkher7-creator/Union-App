window.Auth = Object.freeze((() => {
  const KEY='assoc_admin_session';
  function save(s){sessionStorage.setItem(KEY,JSON.stringify(s));}
  function get(){try{const s=JSON.parse(sessionStorage.getItem(KEY)||'null');return s&&s.expiresAt>Date.now()?s:null;}catch{return null;}}
  function clear(){sessionStorage.removeItem(KEY);}
  function requireAuth(){const s=get();if(!s){location.replace('login.html');return null;}return s;}
  async function logout(){const s=get();try{if(s?.token) await fetch(window.APP_CONFIG.api.baseUrl+'/auth/logout',{method:'POST',headers:{'Authorization':'Bearer '+s.token}});}catch{} clear();location.replace('login.html');}
  return {SESSION_HOURS:0.25,save,get,clear,requireAuth,logout};
})());

// صفحات تسجيل الدخول تحتاج واجهة Auth نفسها، لكن لا يجوز تشغيل حارس الجلسة
// عليها تلقائيًا؛ وإلا سيحدث تحويل login.html -> login.html في حلقة لا نهائية.
(function guardProtectedPage() {
  const path = String(location.pathname || '').toLowerCase();
  const isLoginPage = path.endsWith('/login.html') || path.endsWith('/login.htm') || path.endsWith('/login');
  if (!isLoginPage) window.Auth.requireAuth();
})();
