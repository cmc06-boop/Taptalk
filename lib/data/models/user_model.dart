class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.themeKey,
    this.passwordHash,
    this.firebaseUid,
    this.phoneNumber,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final String? themeKey;
  final String? passwordHash;
  final String? firebaseUid;
  final String? phoneNumber;

  bool get isOnlineAccount =>
      firebaseUid != null && firebaseUid!.trim().isNotEmpty;

  bool get isPhoneAccount => isStubEmail(email);

  static bool isStubEmail(String email) =>
      email.trim().toLowerCase().endsWith('@taptalk.stub');

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
    String? phoneNumber,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      themeKey: themeKey ?? this.themeKey,
      passwordHash: passwordHash ?? this.passwordHash,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
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
        'phone_number': phoneNumber,
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
      phoneNumber: map['phone_number'] as String?,
    );
  }
}

