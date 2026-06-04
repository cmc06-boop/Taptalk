/// Result of [FirebaseService.sendPasswordResetEmail].
class FirebasePasswordResetResult {
  const FirebasePasswordResetResult._({
    required this.success,
    this.errorCode,
  });

  final bool success;
  final String? errorCode;

  factory FirebasePasswordResetResult.sent() =>
      const FirebasePasswordResetResult._(success: true);

  factory FirebasePasswordResetResult.failed({String? errorCode}) =>
      FirebasePasswordResetResult._(success: false, errorCode: errorCode);
}
