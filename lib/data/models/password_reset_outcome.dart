/// Result of starting a password reset from [AppState.beginPasswordReset].
class PasswordResetStartOutcome {
  const PasswordResetStartOutcome._({
    this.error,
    this.emailSent = false,
  });

  final String? error;
  final bool emailSent;

  factory PasswordResetStartOutcome.emailSent() =>
      const PasswordResetStartOutcome._(emailSent: true);

  factory PasswordResetStartOutcome.error(String message) =>
      PasswordResetStartOutcome._(error: message);
}
