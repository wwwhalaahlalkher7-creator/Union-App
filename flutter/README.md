# TRINEX Flutter App

تطبيق Android مبني بـ Flutter. الواجهة تعتمد على TRINEX API ولا تحتوي مفاتيح مزودي AI أو قواعد بيانات مباشرة.

## Quick start

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release build

```bash
flutter build apk --release
flutter build appbundle --release
```

## Version

المصدر الوحيد:

`flutter/VERSION`

بعد تعديل الإصدار:

```bash
python3 tool/sync_version.py
```

## Structure

- `lib/app/` — app shell + routing.
- `lib/core/` — network/storage/theme/update/config.
- `lib/data/` — models + repositories.
- `lib/features/` — screens/features.
- `lib/shared/widgets/` — reusable UI.
- `test/` — focused automated tests.

للمعمارية وسياسة الإصدار راجع `../docs/ARCHITECTURE.md` و`../docs/RELEASE.md`.

## TRINEX UI validation / Mock phase

The main TRINEX student surfaces now load through the existing repository/API layer. Public content uses the public API, while student profile, materials, schedule, XP, badges, progress and notifications use authenticated endpoints. The UI no longer depends on the previous `lib/data/mock_data.dart` fixtures.

## UX Pass 4
Interaction feedback, motion tokens, semantic press states, and UX state guidelines are documented in `docs/UX-PASS-4.md`.
