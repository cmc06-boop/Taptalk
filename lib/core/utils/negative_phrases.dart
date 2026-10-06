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
    return text
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isNegative({
    required String text,
    required String categoryKey,
  }) {
    final category = categoryKey.trim().toLowerCase();
    if (category == 'health_safety') return true;
    return _texts.contains(normalizeText(text));
  }
}
