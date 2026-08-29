class SavedAccount {
  const SavedAccount({
    required this.email,
    required this.displayName,
    required this.role,
    required this.lastUsedAtMs,
    this.firebaseUid,
  });

  final String email;
  final String displayName;
  final String role;
  final int lastUsedAtMs;
  final String? firebaseUid;

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'role': role,
        'lastUsedAtMs': lastUsedAtMs,
        if (firebaseUid != null && firebaseUid!.isNotEmpty)
          'firebaseUid': firebaseUid,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      email: (json['email'] as String?)?.trim() ?? '',
      displayName: (json['displayName'] as String?)?.trim() ?? '',
      role: (json['role'] as String?)?.trim() ?? 'learner',
      lastUsedAtMs: json['lastUsedAtMs'] as int? ?? 0,
      firebaseUid: (json['firebaseUid'] as String?)?.trim(),
    );
  }

  SavedAccount copyWith({
    String? displayName,
    String? role,
    int? lastUsedAtMs,
    String? firebaseUid,
  }) {
    return SavedAccount(
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      lastUsedAtMs: lastUsedAtMs ?? this.lastUsedAtMs,
      firebaseUid: firebaseUid ?? this.firebaseUid,
    );
  }
}
