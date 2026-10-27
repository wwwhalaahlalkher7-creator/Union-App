/* Anonymous, privacy-preserving website usage telemetry. No cookies, IPs, URLs with query strings, or content text are sent. */
(function () {
  'use strict';
  var endpoint = 'https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1/usage/events';
  var allowed = {
    'index.html': 'home', 'news.html': 'news', 'activities.html': 'activities',
    'events.html': 'events', 'injazat.html': 'achievements', 'courses.html': 'materials',
    'download.html': 'other', 'committees.html': 'more'
  };
  function randomId() {
    if (window.crypto && typeof window.crypto.randomUUID === 'function') return window.crypto.randomUUID().replace(/[^a-zA-Z0-9_-]/g, '');
    var bytes = new Uint8Array(24);
    if (window.crypto && window.crypto.getRandomValues) window.crypto.getRandomValues(bytes);
    else for (var i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256);
    return Array.from(bytes, function (b) { return b.toString(16).padStart(2, '0'); }).join('');
  }
  function getSessionId() {
    var key = 'trinex_anon_analytics_v1';
    try {
      var value = localStorage.getItem(key);
      if (!value || !/^[a-zA-Z0-9_-]{16,128}$/.test(value)) {
        value = randomId();
        localStorage.setItem(key, value);
      }
      return value;
    } catch (_) { return randomId(); }
  }
  function sectionForPath() {
    var parts = location.pathname.split('/').filter(Boolean);
    var file = (parts.length ? parts[parts.length - 1] : 'index.html').toLowerCase();
    if (!file.endsWith('.html')) file += '.html';
    return allowed[file] || 'website';
  }
  function send(eventName, section) {
    var payload = JSON.stringify({ sessionId: getSessionId(), platform: 'website', eventName: eventName, section: section || 'website', appVersion: 'website-v1' });
    try {
      fetch(endpoint, { method: 'POST', mode: 'cors', credentials: 'omit', keepalive: true, headers: { 'Content-Type': 'application/json' }, body: payload }).catch(function () {});
    } catch (_) { /* Analytics must never affect website operation. */ }
  }
  try {
    var section = sectionForPath();
    send('page_view', section);
    if (!sessionStorage.getItem('trinex_analytics_session_started')) {
      sessionStorage.setItem('trinex_analytics_session_started', '1');
      send('session_start', section);
    }
  } catch (_) { /* Browsing remains functional if storage or network is unavailable. */ }
})();
