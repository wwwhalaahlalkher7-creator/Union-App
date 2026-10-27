import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leo_association/core/storage/app_preferences.dart';
import 'package:leo_association/core/theme/design_tokens.dart';

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

  test('uses the new four accent presets', () {
    expect(AppAccentColor.presets.map((color) => color.id), [
      'cyan',
      'emerald',
      'amber',
      'sapphire',
      'rose',
      'neon_green',
      'lime',
      'sage_gray',
      'monochrome',
    ]);
    expect(AppAccentColor.fromId('neon_green').primary, const Color(0xFF63F925));
    expect(AppAccentColor.fromId('lime').primary, const Color(0xFFD8EF1B));
    expect(AppAccentColor.fromId('sage_gray').primary, const Color(0xFFBCC4BA));
    expect(AppAccentColor.fromId('monochrome').primary, Colors.black);
    expect(AppAccentColor.fromId('monochrome').primaryDark, Colors.white);
    expect(AppAccentColor.fromId('monochrome').isThemeAdaptive, isTrue);
  });

}
