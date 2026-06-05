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

  test('lesson phrase in Tagalog translates when language is English', () {
    expect(
      ContentLocalization.freeText('Gusto ko ng tubig', AppLanguage.english),
      'I want water',
    );
  });

  test('lesson title word translates to Filipino', () {
    expect(
      ContentLocalization.freeText('Food', AppLanguage.filipino),
      'pagkain',
    );
  });

  test('stored English lesson phrase shows Filipino in Filipino mode', () {
    expect(
      ContentLocalization.phrase('I am happy', 'lesson', lang: AppLanguage.filipino),
      'Masaya ako',
    );
  });

  test('stored Tagalog lesson phrase shows English in English mode', () {
    expect(
      ContentLocalization.phrase('Gusto ko ng tubig', 'lesson', lang: AppLanguage.english),
      'I want water',
    );
  });

  test('Pangit ka translates to You are ugly in English', () {
    expect(ContentLocalization.canonicalPhrase('Pangit ka'), 'You are ugly');
    expect(
      ContentLocalization.phrase('Pangit ka', 'lesson', lang: AppLanguage.english),
      'You are ugly',
    );
  });

  test('You are ugly displays as Pangit ka in Filipino', () {
    expect(
      ContentLocalization.phrase('You are ugly', 'lesson', lang: AppLanguage.filipino),
      'Pangit ka',
    );
  });
}
