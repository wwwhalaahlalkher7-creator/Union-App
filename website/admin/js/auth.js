const Auth = (() => {
  const KEY='assoc_admin_session';
  const ROLE_ALIASES={
    'مدير عام':'super_admin','محرر محتوى':'content_manager','مسؤول أكاديمي':'academic_manager','مشرف':'moderator',
    'super admin':'super_admin','administrator':'super_admin','admin':'super_admin',
    'content manager':'content_manager','academic manager':'academic_manager','moderator':'moderator',
    'super_admin':'super_admin','content_manager':'content_manager','academic_manager':'academic_manager'
  };
  function normalizeRole(value){
    if(value===null||value===undefined)return '';
    const raw=String(value).normalize('NFKC').replace(/[\u064B-\u065F\u0670]/g,'').replace(/\s+/g,' ').trim();
    const key=raw.toLowerCase(); return ROLE_ALIASES[raw]||ROLE_ALIASES[key]||raw;
  }
  function normalizeSession(s){ if(!s||typeof s!=='object')return null; const role=normalizeRole(s.role); return role===s.role?s:{...s,role}; }

  function save(s){sessionStorage.setItem(KEY,JSON.stringify(normalizeSession(s)));}
  function get(){try{const s=normalizeSession(JSON.parse(sessionStorage.getItem(KEY)||'null'));if(s&&s.expiresAt>Date.now()){if(s.role!==JSON.parse(sessionStorage.getItem(KEY)||'null')?.role)sessionStorage.setItem(KEY,JSON.stringify(s));return s;}return null;}catch{return null;}}
  function clear(){sessionStorage.removeItem(KEY);}
  function requireAuth(){const s=get();if(!s){location.replace('login.html');return null;}return s;}
  async function logout(){const s=get();try{if(s?.token) await fetch(window.APP_CONFIG.api.baseUrl+'/auth/logout',{method:'POST',headers:{'Authorization':'Bearer '+s.token}});}catch{} clear();location.replace('login.html');}
  return {SESSION_HOURS:0.25,save,get,clear,requireAuth,logout,normalizeRole};
})();
window.Auth = Object.freeze(Auth);

// صفحات تسجيل الدخول تحتاج واجهة Auth نفسها، لكن لا يجوز تشغيل حارس الجلسة
// عليها تلقائيًا؛ وإلا سيحدث تحويل login.html -> login.html في حلقة لا نهائية.
(function guardProtectedPage() {
  const path = String(location.pathname || '').toLowerCase();
  const isLoginPage = path.endsWith('/login.html') || path.endsWith('/login.htm') || path.endsWith('/login');
  if (!isLoginPage) Auth.requireAuth();
})();
