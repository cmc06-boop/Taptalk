class HistoryModel {
  const HistoryModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.categoryKey,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String text;
  final String categoryKey;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'phrase_text': text,
        'category_key': categoryKey,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory HistoryModel.fromMap(Map<String, Object?> map) {
    return HistoryModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      text: map['phrase_text'] as String,
      categoryKey: map['category_key'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
