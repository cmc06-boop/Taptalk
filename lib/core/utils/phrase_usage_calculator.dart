import '../../data/models/phrase_usage_stat.dart';
import '../l10n/content_localization.dart';

/// Shared identity for monitoring only. Original history text is preserved.
abstract final class PhraseUsageCalculator {
  static String _clean(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');

  // Warning vocabulary not covered by the general content translator.
  static const _aliases = {
    'iyak': 'cry',
    'hiya': 'shame',
    'nahihiya': 'embarrassed',
    'selos': 'jealous',
    'awa': 'pity',
    'nalilito': 'confused',
    'ayaw ko': "i don't like",
    'i dont like': "i don't like",
    'hindi ko maintindihan': "i don't understand",
    'i dont understand': "i don't understand",
    'tulungan mo ako': 'help me',
    'emerhensiya': 'emergency',
  };

  static String phraseKey(String text) {
    final clean = _clean(text);
    return _aliases[clean] ??
        _clean(ContentLocalization.canonicalPhrase(clean));
  }

  /// Combines language variants within a category without inflating its usage.
  static List<PhraseUsageStat> mergeByCategory(
    Iterable<PhraseUsageStat> stats,
  ) {
    final merged = <String, PhraseUsageStat>{};
    for (final stat in stats) {
      final phrase = phraseKey(stat.text);
      if (phrase.isEmpty) continue;
      final key = '${stat.categoryKey}|$phrase';
      final previous = merged[key];
      merged[key] = PhraseUsageStat(
        text: previous?.text ?? stat.text,
        categoryKey: stat.categoryKey,
        count: (previous?.count ?? 0) + stat.count,
      );
    }
    return merged.values.toList();
  }

  static Map<String, int> totals(Iterable<PhraseUsageStat> stats) {
    final totals = <String, int>{};
    for (final stat in stats) {
      final key = phraseKey(stat.text);
      if (key.isEmpty) continue;
      totals[key] = (totals[key] ?? 0) + stat.count;
    }
    return totals;
  }

  /// Category selection locates a phrase; the displayed count belongs to the
  /// phrase across all categories, just like the daily warning threshold.
  static List<PhraseUsageStat> withPhraseTotals(
    Iterable<PhraseUsageStat> stats,
  ) {
    final grouped = mergeByCategory(stats);
    final counts = totals(grouped);
    return [
      for (final stat in grouped)
        PhraseUsageStat(
          text: stat.text,
          categoryKey: stat.categoryKey,
          count: counts[phraseKey(stat.text)]!,
        ),
    ];
  }
}
