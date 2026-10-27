# Phase 10 — CI follow-up fixes

This phase addresses the failures reported after Phase 9:

- Static analysis no longer fails solely because of informational style/deprecation lints. Analyzer warnings and errors remain fatal. Removed the unused local `active` value from the academic record card.
- The Android workflow explicitly sets the generated app's `compileSdk` to Android API 36, as required by the resolved `flutter_plugin_android_lifecycle` dependency. This does not change `targetSdk` or `minSdk`.
- The iOS simulator workflow no longer requests `--release`, which Flutter does not support for simulator builds. It compiles the simulator target without code signing. This is not a signed, device-installable iOS release.

Validation note: this environment does not have the Flutter SDK, so `flutter analyze`, `flutter test`, and platform builds have not been run locally. The GitHub Actions workflow is the required verification.
