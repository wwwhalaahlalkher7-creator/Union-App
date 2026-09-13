const SECURITY_HEADERS = {
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'referrer-policy': 'strict-origin-when-cross-origin',
  'permissions-policy': 'camera=(), microphone=(), geolocation=(), payment=()',
  'content-security-policy': "default-src 'self'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://fonts.googleapis.com; font-src 'self' https://cdnjs.cloudflare.com https://fonts.gstatic.com data:; img-src 'self' data: https:; connect-src 'self' https://leo-association-api.www-halaahlalkher7.workers.dev",
};

function withSecurityHeaders(response) {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) headers.set(key, value);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

function assetRequestForDashboard(request) {
  const url = new URL(request.url);

  // The public site owns the root domain. The dashboard owns only /admin.
  // When this Worker is attached to the final domain, /admin/* is rewritten
  // to the dashboard asset root. On workers.dev the same /admin path remains
  // available for verification.
  if (url.pathname === '/admin' || url.pathname === '/admin/') {
    url.pathname = '/';
  } else if (url.pathname.startsWith('/admin/')) {
    url.pathname = url.pathname.slice('/admin'.length) || '/';
  } else {
    url.pathname = '/__dashboard_outside_admin__';
  }

  return new Request(url, request);
}

export default {
  async fetch(request, env) {
    const originalPath = new URL(request.url).pathname;
    if (originalPath !== '/admin' && originalPath !== '/admin/' && !originalPath.startsWith('/admin/')) {
      return withSecurityHeaders(new Response('Not Found', { status: 404 }));
    }
    const response = await env.ASSETS.fetch(assetRequestForDashboard(request));
    return withSecurityHeaders(response);
  },
};
