import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/core/localization/app_localizations.dart';

void main() {
  test('supported locales expose core TRINEX strings', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      expect(l10n.t('appName'), 'TRINEX');
      expect(l10n.t('home'), isNotEmpty);
      expect(l10n.t('materials'), isNotEmpty);
      expect(l10n.t('schedule'), isNotEmpty);
      expect(l10n.t('settings'), isNotEmpty);
      expect(l10n.t('materialSearch'), isNotEmpty);
    }
  });
}
