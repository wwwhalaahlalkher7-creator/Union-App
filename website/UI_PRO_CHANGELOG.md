# Leo UI Pro — Website Refresh

## Scope

This release is a front-end redesign of the public website only.

### Preserved
- Existing HTML IDs used by the current JavaScript.
- Existing page URLs and navigation destinations.
- Existing Google Apps Script / Airtable / Drive integrations.
- Existing analytics and ad-manager scripts.
- Existing dynamic rendering and modal/lightbox behavior.
- Existing admin/backend API contract.
- Existing site branding text and configurable public site settings.

### New design direction
- Mobile-first responsive layout.
- Dark premium editorial/academic visual system.
- Default public accent: `#7C5CFF`.
- Accent remains controlled by the existing **SiteThemeColor** setting.
- Added `--primary-rgb` so the accent can drive glows and interactive effects consistently.
- Refined glass header while keeping the same navigation structure.
- Interactive pointer spotlight background on capable devices.
- Scroll reveal animation for cards and major sections.
- Refined cards, buttons, filters, search bars, forms, statistics, modals, and course/file views.
- Reduced-motion support for accessibility.
- Arabic typography upgraded to IBM Plex Sans Arabic.

### Small compatibility fix
The admin theme bridge now exposes `previewSite()` because the settings page already calls that method for live site-color preview. This does not change any backend endpoint or stored-data format.


## v5-lightweight (based on v4)
- Reverted public identity color to the original orange `#FF9100` / `#FFB45C`.
- Preserved dashboard-controlled theme color; only the old v4 purple `#7C5CFF` is migrated back to orange.
- Removed pointer-following spotlight and card pointer tracking.
- Removed expensive card backdrop blur and shimmer layers.
- Reduced header/overlay blur.
- Replaced broad per-card reveal observation with lightweight page-level reveals.
- Added a lightweight engineering ambient animation using CSS transforms only (no logo, canvas, images, or pointer tracking).
- Disabled global smooth scrolling to restore native, lighter mobile scrolling.
