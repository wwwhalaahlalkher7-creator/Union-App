# Security Policy

## Reporting a vulnerability

Please do not report security vulnerabilities through public GitHub issues.

For a private report, contact the project maintainer through the private security
channel configured for this repository. Include enough detail to reproduce the
issue safely, but do not include real student data, credentials, API keys, or
other sensitive information.

## Scope

Security-sensitive areas include:

- Authentication and session handling
- Staff/admin authorization
- Public and admin API endpoints
- Cloudflare Worker and D1 access
- Eino provider credentials and routing
- Website/admin XSS and browser security controls
- Android release signing and update mechanisms

## Secrets

Never commit:

- `.env` files containing real values
- Cloudflare, Mistral, Groq, Free.ai, or Google tokens
- Android keystores or `key.properties`
- Student exports or production database dumps
- Access or refresh tokens

See `docs/SECURITY.md` and `docs/CONFIGURATION.md` for the operational security baseline.
