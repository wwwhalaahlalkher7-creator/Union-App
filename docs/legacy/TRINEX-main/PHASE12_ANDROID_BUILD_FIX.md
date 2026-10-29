# Phase 12 — Android compile SDK enforcement

The previous CI patch only matched Gradle declarations written as `compileSdk = ...` or `compileSdkVersion ...`. Some Flutter plugin Gradle files use the Groovy form `compileSdk flutter.compileSdkVersion`, so the plugin could remain at API 34 even when the app was updated.

The Android workflow now:
- resolves plugin roots from `.dart_tool/package_config.json`;
- rewrites supported `compileSdk` / `compileSdkVersion` declaration forms in the app and plugin Gradle files to API 36;
- explicitly verifies the selected `file_picker` and `flutter_plugin_android_lifecycle` plugin files are set to API 36 before starting the APK build;
- stops early with a clear diagnostic if either plugin cannot be located or updated.

This is a CI-time compatibility workaround. A real `flutter build apk --release` run is still required to confirm the artifact builds successfully.
