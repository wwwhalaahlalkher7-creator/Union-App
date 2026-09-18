import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leo_association/core/storage/app_preferences.dart';

void main() {
  test('uses Amber as the default accent', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences();
    await preferences.init();

    expect(preferences.accentColorId, 'amber');
  });

  test('persists a selected accent', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences();
    await preferences.init();

    await preferences.setAccentColorId('emerald');

    expect(preferences.accentColorId, 'emerald');
  });
}
