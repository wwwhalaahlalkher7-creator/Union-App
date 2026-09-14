const SECURITY_HEADERS = {
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'SAMEORIGIN',
  'referrer-policy': 'strict-origin-when-cross-origin',
  'permissions-policy': 'camera=(), microphone=(), geolocation=(), payment=()',
  'cross-origin-opener-policy': 'same-origin',
  'x-permitted-cross-domain-policies': 'none',
  'origin-agent-cluster': '?1',
  'content-security-policy': "default-src 'self'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'; object-src 'none'; frame-src 'none'; worker-src 'self'; manifest-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://fonts.googleapis.com; font-src 'self' https://cdnjs.cloudflare.com https://fonts.gstatic.com data:; img-src 'self' data: https:; connect-src 'self' https://leo-association-api.www-halaahlalkher7.workers.dev; upgrade-insecure-requests;",
};

function withSecurityHeaders(response) {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) headers.set(key, value);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let path = url.pathname;

    // Keep /admin as the public URL for the existing dashboard source.
    // The deployment workflow places website/dashboard under dist/admin/.
    if (path === '/admin') path = '/admin/';
    if (path.endsWith('/')) path += 'index.html';

    const assetUrl = new URL(request.url);
    assetUrl.pathname = path;
    const response = await env.ASSETS.fetch(new Request(assetUrl, request));

    // Static assets should be served as-is except for the common security headers.
    return withSecurityHeaders(response);
  },
};
