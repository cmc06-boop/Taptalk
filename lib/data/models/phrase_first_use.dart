class PhraseFirstUse {
  const PhraseFirstUse({
    required this.text,
    required this.categoryKey,
    required this.firstUsedAt,
  });

  final String text;
  final String categoryKey;
  final DateTime firstUsedAt;
}
