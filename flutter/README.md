# TRINEX Flutter App

تطبيق Android مبني بـ Flutter. الواجهة تعتمد على TRINEX API ولا تحتوي مفاتيح مزودي AI أو قواعد بيانات مباشرة.

## Quick start

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter pub get` resolves the exact dependency graph and creates `pubspec.lock`.
Keep that generated file next to `pubspec.yaml` under version control so local builds and CI use the same package versions. The CI workflow also uploads its resolver-generated lockfile as the `trinex-pubspec-lock-<commit>` artifact when it runs; use that artifact if you need to add the resolved file from a Flutter-enabled runner.

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
