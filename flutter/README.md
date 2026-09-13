# TRINEX — Flutter App

## Release 1.1

This release takes the initial AI-generated foundation and aligns it with the
agreed product plan.

### Current direction

- Guest-first usage.
- Optional student account deferred for a later release.
- TRINEX home / Materials / Schedule / Notifications / Student navigation.
- Unified navy / orange visual system inspired by the TRINEX brand board.
- Branded Android launcher icon and navy native splash.
- Arabic / English / French localization.
- Theme persistence.
- API client with GET/POST support.
- Backend repositories for news, announcements, activities, achievements and
  materials.
- No commercial ads.

The app must remain usable without student authentication.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```
