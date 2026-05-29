class LinkedChildModel {
  const LinkedChildModel({
    required this.learnerId,
    required this.fullName,
    required this.profileCode,
    required this.linkedAt,
  });

  final int learnerId;
  final String fullName;
  final String profileCode;
  final DateTime linkedAt;

  factory LinkedChildModel.fromMap(Map<String, Object?> map) {
    return LinkedChildModel(
      learnerId: map['learner_user_id'] as int,
      fullName: map['full_name'] as String,
      profileCode: (map['profile_code'] as String?) ?? '',
      linkedAt: DateTime.fromMillisecondsSinceEpoch(map['linked_at'] as int),
    );
  }
}
