import 'package:flutter_application_1/core/l10n/app_strings.dart';
import 'package:flutter_application_1/core/l10n/content_localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('I am Hungry translates to Gutom ako in Filipino', () {
    expect(
      ContentLocalization.phrase('I am Hungry', 'food', lang: AppLanguage.filipino),
      'Gutom ako',
    );
  });

  test('Gutom ako canonicalizes to I am hungry', () {
    expect(ContentLocalization.canonicalPhrase('Gutom ako'), 'I am hungry');
  });

  test('Gutom ako displays as I am hungry in English', () {
    expect(
      ContentLocalization.phrase('Gutom ako', 'food', lang: AppLanguage.english),
      'I am hungry',
    );
  });
}
