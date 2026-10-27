# Phase 11 — Android compile SDK enforcement

## CI failure addressed
The Android release build still failed during `:file_picker:checkReleaseAarMetadata` because a Flutter plugin module was being compiled against Android API 34 while `flutter_plugin_android_lifecycle` requires API 36 or newer.

## Change
The Android CI job now runs a post-`flutter pub get` step that enforces `compileSdk` / `compileSdkVersion` 36 in the generated app Gradle file **and** the Android Gradle files for downloaded Flutter plugins in the Pub cache. The previous step changed only the app module, which was insufficient for the plugin-module mismatch shown in the build log.

`targetSdk` and `minSdk` are not changed by this step. It does not claim that the APK build passed; GitHub Actions must run the updated workflow to verify the fix.
