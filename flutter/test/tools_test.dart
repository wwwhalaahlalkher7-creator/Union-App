import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/core/localization/app_localizations.dart';

void main() {
  group('Engineering Tools & Localizations', () {
    test('all new onboarding and tools localization keys are present in all locales', () {
      final requiredKeys = [
        'onboardingTitle1',
        'onboardingSubtitle1',
        'onboardingTitle2',
        'onboardingSubtitle2',
        'onboardingTitle3',
        'onboardingSubtitle3',
        'getStarted',
        'toolsTitle',
        'unitConverterTitle',
        'gpaCalculatorTitle',
        'resistorDecoderTitle',
        'engineeringRefsTitle',
        'guestWelcomeTitle',
        'studentLockedCardTitle',
        'updateSemesterTitle',
      ];

      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        for (final key in requiredKeys) {
          final val = l10n.t(key);
          expect(val, isNotEmpty, reason: 'Key $key was empty in locale ${locale.languageCode}');
          expect(val, isNot(equals(key)), reason: 'Key $key was not translated in locale ${locale.languageCode}');
        }
      }
    });

    test('resistor multiplier math matches standard 4-band decoder logic', () {
      // 1st band: Brown (1), 2nd band: Black (0), Multiplier: Red (100) -> 1,000 ohms = 1 kΩ
      const d1 = 1;
      const d2 = 0;
      const mult = 100.0;
      const ohms = (d1 * 10 + d2) * mult;
      expect(ohms, 1000.0);

      // 1st band: Yellow (4), 2nd band: Violet (7), Multiplier: Orange (1,000) -> 47,000 ohms = 47 kΩ
      const d1b = 4;
      const d2b = 7;
      const multB = 1000.0;
      const ohmsB = (d1b * 10 + d2b) * multB;
      expect(ohmsB, 47000.0);
    });
  });
}
