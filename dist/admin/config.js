window.APP_CONFIG = {
  site: {
    name: 'TRINEX',
    shortName: 'لوحة TRINEX',
    org: 'كلية الهندسة والعمارة',
    logoUrl: 'assets/trinex_icon.png',
    publicUrl: (typeof window !== 'undefined' && window.location && window.location.hostname !== 'ush-eng.great-site.net') ? '/' : 'https://ush-eng.great-site.net',
    dashboardUrl: (typeof window !== 'undefined' && window.location && window.location.hostname !== 'ush-eng.great-site.net') ? '/admin/' : 'https://ush-eng.great-site.net/admin/'
  },
  api: {
    baseUrl: (typeof window !== 'undefined' && window.location && window.location.hostname !== 'ush-eng.great-site.net') ? (window.location.origin + '/api/v1') : 'https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1'
  },
  modules: {
    dashboard:true, students:true, schedule:true, materials:true, news:true,
    ads:false, users:true, security:true, settings:true
  }
};
