class FavoriteModel {
  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.phraseText,
    required this.categoryKey,
    this.phraseId,
    this.imagePath,
  });

  final int id;
  final int userId;
  final String phraseText;
  final String categoryKey;
  final int? phraseId;
  final String? imagePath;

  String get dedupeKey => '${phraseText.trim().toLowerCase()}__$categoryKey';

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'phrase_text': phraseText,
        'category_key': categoryKey,
        'phrase_id': phraseId,
        'image_path': imagePath,
      };

  factory FavoriteModel.fromMap(Map<String, Object?> map) {
    return FavoriteModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      phraseText: map['phrase_text'] as String,
      categoryKey: map['category_key'] as String,
      phraseId: map['phrase_id'] as int?,
      imagePath: map['image_path'] as String?,
    );
  }
}
