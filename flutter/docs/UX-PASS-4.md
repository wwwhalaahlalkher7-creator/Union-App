# UX Pass 4 — Interaction & Polish

- Every async surface should expose loading, empty, error and retry states.
- User actions receive immediate tactile feedback.
- Motion is short and purposeful and should respect reduced-motion settings.
- Icon-only actions require semantic labels/tooltips.
- Touch targets target 48dp.

## Motion
- Micro feedback: 140ms
- Component transitions: 220ms
- Page transitions: 300ms
- Enter: easeOutCubic; exit: easeInCubic

## Offline/error language
- No internet: explain the connection issue and provide Retry.
- Server error: explain temporary unavailability and provide Retry.
- Empty: explain that there is currently no content; do not present it as an error.

## Gamification
XP and badges are feedback layers, not barriers. Never fabricate XP or imply a reward unless confirmed by application state.
