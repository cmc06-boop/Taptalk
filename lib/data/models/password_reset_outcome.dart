/// Result of starting a password reset from [AppState.beginPasswordReset].
class PasswordResetStartOutcome {
  const PasswordResetStartOutcome._({
    this.error,
    this.emailSent = false,
    this.localPasswordStep = false,
  });

  final String? error;
  final bool emailSent;
  final bool localPasswordStep;

  factory PasswordResetStartOutcome.emailSent() =>
      const PasswordResetStartOutcome._(emailSent: true);

  factory PasswordResetStartOutcome.localPasswordStep() =>
      const PasswordResetStartOutcome._(localPasswordStep: true);

  factory PasswordResetStartOutcome.error(String message) =>
      PasswordResetStartOutcome._(error: message);
}
