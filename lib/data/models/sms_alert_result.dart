class SmsAlertResult {
  const SmsAlertResult({
    required this.attempted,
    required this.sent,
    required this.failed,
    this.invalidContacts = const [],
    this.errorMessage,
    this.sentViaDevice = false,
    this.openedComposer = false,
  });

  final int attempted;
  final int sent;
  final int failed;
  final List<String> invalidContacts;
  final String? errorMessage;
  /// True when SMS used the phone's cellular SIM (works without internet).
  final bool sentViaDevice;
  /// True when silent send failed and the Messages app was opened instead.
  final bool openedComposer;

  bool get isSuccess => errorMessage == null && sent > 0;

  static const empty = SmsAlertResult(attempted: 0, sent: 0, failed: 0);
}

class TeacherAlertDeliveryResult {
  const TeacherAlertDeliveryResult({
    required this.inAppError,
    required this.sms,
  });

  final String? inAppError;
  final SmsAlertResult sms;

  bool get inAppSent => inAppError == null;
}
