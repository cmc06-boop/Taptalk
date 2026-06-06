/// Helpers for parsing teacher class names (e.g. "English 1 - Sampaguita").
class ClassNameUtils {
  ClassNameUtils._();

  /// Returns the subject portion before the section separator.
  ///
  /// Examples:
  /// - "English 1 - Sampaguita" → "English 1"
  /// - "English 1-Sampaguita" → "English 1"
  /// - "Math" → "Math"
  static String subjectFrom(String className) {
    final trimmed = className.trim();
    if (trimmed.isEmpty) return trimmed;

    final separator = RegExp(r'\s*-\s*');
    final parts = trimmed.split(separator);
    if (parts.length < 2) return trimmed;

    final subject = parts.first.trim();
    return subject.isEmpty ? trimmed : subject;
  }
}
