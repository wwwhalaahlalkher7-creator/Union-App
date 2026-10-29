# Phase 9 — Build error fixes

## Dart parser errors fixed

- `lib/src/features/content/content_page.dart`: closed the nested `SizedBox`/scroll/form widgets before the `AlertDialog.actions` argument.
- `lib/src/features/settings/settings_page.dart`: closed the nested dialog content widgets before `actions`.
- `lib/src/features/users/users_page.dart`: rewrote student and staff dialog builders into readable multiline Dart and corrected the widget nesting/parentheses.
- `lib/src/features/security/security_page.dart`: removed `const` from the `RegExp` local because `RegExp` is not a const constructor.

These were source-code errors causing both Android and Windows compilation to fail.

## iOS signing

The iOS Xcode build reached the signing stage. A device-installable iOS release requires an Apple Development Team and a valid provisioning profile/bundle identifier. Those are Apple account/project settings and cannot safely be fabricated in source code. The CI validation workflow now builds for the iOS simulator without signing; this validates compilation but does not create an installable iPhone IPA.

## Validation status

The four changed Dart files were checked for balanced delimiters in this environment. Flutter/Dart SDK is unavailable here, so `dart format`, `flutter analyze`, `flutter test`, and platform builds still need to run in CI. Do not treat this archive as a confirmed successful build until those jobs pass.
