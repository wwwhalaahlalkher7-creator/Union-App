const Auth = (() => {
  const KEY='assoc_admin_session';
  function save(s){localStorage.setItem(KEY,JSON.stringify(s));}
  function get(){try{const s=JSON.parse(localStorage.getItem(KEY)||'null');return s&&s.expiresAt>Date.now()?s:null;}catch{return null;}}
  function clear(){localStorage.removeItem(KEY);}
  function requireAuth(){const s=get();if(!s){location.replace('login.html');return null;}return s;}
  async function logout(){const s=get();try{if(s?.token) await fetch(window.APP_CONFIG.api.baseUrl+'/auth/logout',{method:'POST',headers:{'Authorization':'Bearer '+s.token}});}catch{} clear();location.replace('login.html');}
  return {SESSION_HOURS:0.25,save,get,clear,requireAuth,logout};
})();
Auth.requireAuth();
