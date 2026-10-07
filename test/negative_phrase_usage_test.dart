import 'package:flutter_application_1/core/utils/negative_phrases.dart';
import 'package:flutter_application_1/core/utils/phrase_usage_calculator.dart';
import 'package:flutter_application_1/data/models/phrase_usage_stat.dart';
import 'package:flutter_application_1/data/repositories/app_repository.dart';
import 'package:flutter_test/flutter_test.dart';

PhraseUsageStat stat(String text, int count, [String category = 'needs']) =>
    PhraseUsageStat(text: text, categoryKey: category, count: count);

void main() {
  test('English and Filipino variants use the same phrase identity', () {
    for (final pair in [
      ('Help', 'Tulong'),
      ('Sad', 'Malungkot'),
      ('Angry', 'Galit'),
      ('Scared', 'Takot'),
      ('Stop', 'Tumigil'),
      ('No', 'Hindi'),
      ("I don't like", 'Ayaw ko'),
      ("I don't understand", 'Hindi ko maintindihan'),
      ('I am hungry', 'Gutom ako'),
      ('Hurt', 'Masakit'),
    ]) {
      expect(
        PhraseUsageCalculator.phraseKey(pair.$1),
        PhraseUsageCalculator.phraseKey(pair.$2),
        reason: '${pair.$1} / ${pair.$2}',
      );
    }
  });

  test(
    'ten uses are per phrase across categories and languages, not ten total negative uses',
    () {
      final totals = NegativePhrases.dailyTotals([
        stat('Help', 3),
        stat('Tulong', 3),
        stat('Help', 4, 'health_safety'),
        stat('Sad', 8, 'emotions'),
        stat('Water', 30, 'drinks'),
      ]);
      expect(totals, {'help': 10, 'sad': 8});
    },
  );

  test(
    'a phrase recognized in Health & Safety includes its uses in other categories',
    () {
      expect(
        NegativePhrases.dailyTotals([
          stat('Chest Pain', 4, 'health_safety'),
          stat('Chest Pain', 6, 'custom'),
        ]),
        {'chest pain': 10},
      );
    },
  );

  test(
    'warning levels survive changing language and category on consecutive days',
    () {
      final today = NegativePhrases.dailyTotals([stat('Tulong', 10)]);
      final yesterday = PhraseUsageCalculator.totals([
        stat('Help', 10, 'health_safety'),
      ]);
      final before = PhraseUsageCalculator.totals([
        stat('Tulong', 5),
        stat('Help', 5),
      ]);
      expect(
        NegativePhrases.warningLevel(
          today: today['help']!,
          yesterday: yesterday['help']!,
          twoDaysAgo: before['help']!,
        ),
        3,
      );
      expect(
        NegativePhrases.warningLevel(today: 10, yesterday: 10, twoDaysAgo: 9),
        2,
      );
      expect(
        NegativePhrases.warningLevel(today: 10, yesterday: 9, twoDaysAgo: 10),
        1,
      );
      expect(
        NegativePhrases.warningLevel(today: 9, yesterday: 10, twoDaysAgo: 10),
        0,
      );
    },
  );

  test(
    'cloud/local merge aggregates variants within each source before taking the overlap maximum',
    () {
      final merged = AppRepository.mergePhraseUsageStats(
        [stat('Help', 3), stat('Tulong', 7)],
        [stat('Help', 10)],
      );
      expect(merged, hasLength(1));
      expect(merged.single.count, 10);
      expect(PhraseUsageCalculator.totals(merged), {'help': 10});
    },
  );
}
