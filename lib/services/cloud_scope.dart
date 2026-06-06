/// TapTalk cloud usage policy.
///
/// Online-only: sign up, log in, forgot password, push notifications,
/// and parent/teacher monitoring (learner activity sync).
/// Most other app data (phrases, classes, etc.) stays in local SQLite.
class CloudScope {
  CloudScope._();

  static const auth = true;
  static const notifications = true;

  /// Full cloud sync for classes, enrollments, lessons, and profiles.
  static const appData = false;

  /// Learner activity, categories, class codes, enrollments, and lesson
  /// content for cross-device parent/teacher monitoring and class join.
  static const monitoring = true;

  static bool get syncMonitoring => appData || monitoring;
}
