class PhraseModel {
  const PhraseModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.categoryKey,
    this.imagePath,
    this.isBuiltin = false,
    this.isActive = true,
  });

  final int id;
  final int userId;
  final String text;
  final String categoryKey;
  final String? imagePath;
  final bool isBuiltin;
  final bool isActive;

  PhraseModel copyWith({
    int? id,
    int? userId,
    String? text,
    String? categoryKey,
    String? imagePath,
    bool? isBuiltin,
    bool? isActive,
  }) {
    return PhraseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      categoryKey: categoryKey ?? this.categoryKey,
      imagePath: imagePath ?? this.imagePath,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'phrase_text': text,
        'category_key': categoryKey,
        'image_path': imagePath,
        'is_builtin': isBuiltin ? 1 : 0,
        'is_active': isActive ? 1 : 0,
      };

  factory PhraseModel.fromMap(Map<String, Object?> map) {
    return PhraseModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      text: map['phrase_text'] as String,
      categoryKey: map['category_key'] as String,
      imagePath: map['image_path'] as String?,
      isBuiltin: (map['is_builtin'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}
