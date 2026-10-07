import '../../data/models/phrase_usage_stat.dart';
import '../constants/monitoring_constants.dart';
import 'phrase_usage_calculator.dart';

/// Built-in negative / distress phrases that can trigger a teacher warning.
abstract final class NegativePhrases {
  static const _texts = {
    'angry',
    'galit',
    'cry',
    'iyak',
    'fear',
    'takot',
    'embarrassed',
    'jealous',
    'pity',
    'sad',
    'malungkot',
    'scared',
    'shame',
    'hiya',
    'confused',
    'no',
    'hindi',
    "i don't like",
    'i dont like',
    'ayaw ko',
    "i don't understand",
    'i dont understand',
    'stop',
    'tumigil',
    'hurt',
    'masakit',
    'help',
    'tulong',
    'help me',
    'emergency',
  };

  static String normalizeText(String text) {
    return PhraseUsageCalculator.phraseKey(text);
  }

  static Map<String, int> dailyTotals(List<PhraseUsageStat> stats) {
    final negativeKeys = {
      for (final stat in stats)
        if (isNegative(text: stat.text, categoryKey: stat.categoryKey))
          normalizeText(stat.text),
    };
    return PhraseUsageCalculator.totals(stats)
      ..removeWhere((key, _) => !negativeKeys.contains(key));
  }

  static int warningLevel({
    required int today,
    required int yesterday,
    required int twoDaysAgo,
  }) {
    if (today < MonitoringConstants.negativeUsageWarningCount) return 0;
    if (yesterday < MonitoringConstants.negativeUsageWarningCount) return 1;
    if (twoDaysAgo < MonitoringConstants.negativeUsageWarningCount) return 2;
    return MonitoringConstants.maxNegativeWarningLevel;
  }

  static bool isNegative({required String text, required String categoryKey}) {
    final category = categoryKey.trim().toLowerCase();
    if (category == 'health_safety') return true;
    return _texts.contains(normalizeText(text));
  }
}
