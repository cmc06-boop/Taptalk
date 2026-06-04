enum PasswordStrength { empty, weak, strong }

/// Shared validation for sign-up, log-in, and password changes.
abstract final class AuthValidation {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\+=\[\]\\;/]');

  static const int minPasswordLength = 8;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) return false;
    return _emailRegex.hasMatch(normalized);
  }

  static bool isValidFullName(String name) => name.trim().length >= 2;

  static bool isStrongPassword(String password) {
    if (password.length < minPasswordLength) return false;
    if (!_uppercase.hasMatch(password)) return false;
    if (!_lowercase.hasMatch(password)) return false;
    if (!_digit.hasMatch(password)) return false;
    if (!_special.hasMatch(password)) return false;
    return true;
  }

  static PasswordStrength evaluatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    if (isStrongPassword(password)) return PasswordStrength.strong;
    return PasswordStrength.weak;
  }
}
