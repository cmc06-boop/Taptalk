({String subject, String gradeSection}) parseClassDisplayName(String className) {
  final match =
      RegExp(r'^([A-Za-z]+)[\s\-]+(.+)$').firstMatch(className.trim());
  if (match != null) {
    return (
      subject: match.group(1)!,
      gradeSection: match.group(2)!.trim(),
    );
  }
  return (subject: className, gradeSection: '');
}
