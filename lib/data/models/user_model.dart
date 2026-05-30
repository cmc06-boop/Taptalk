class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.themeKey,
    this.passwordHash,
    this.firebaseUid,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final String? themeKey;
  final String? passwordHash;
  final String? firebaseUid;

  bool get isOnlineAccount =>
      firebaseUid != null && firebaseUid!.trim().isNotEmpty;

  bool get isLearner => role == 'learner';
  bool get isParent => role == 'parent';
  bool get isTeacher => role == 'teacher';
  bool get needsTheme => isLearner && (themeKey == null || themeKey!.isEmpty);

  UserModel copyWith({
    int? id,
    String? email,
    String? fullName,
    String? role,
    String? themeKey,
    String? passwordHash,
    String? firebaseUid,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      themeKey: themeKey ?? this.themeKey,
      passwordHash: passwordHash ?? this.passwordHash,
      firebaseUid: firebaseUid ?? this.firebaseUid,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'theme': themeKey,
        'password_hash': passwordHash,
        'firebase_uid': firebaseUid,
      };

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      themeKey: map['theme'] as String?,
      passwordHash: map['password_hash'] as String?,
      firebaseUid: map['firebase_uid'] as String?,
    );
  }
}
