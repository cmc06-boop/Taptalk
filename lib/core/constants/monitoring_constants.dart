abstract final class MonitoringConstants {
  /// Phrases must be used at least this many times to appear as "frequently used".
  static const int frequentlyUsedMinCount = 5;

  /// How far back parent/teacher cloud pulls reach for learner phrase activity.
  static const int cloudActivityPullDays = 365 * 3;

  static DateTime cloudActivityPullRangeStart() {
    return DateTime.now().subtract(const Duration(days: cloudActivityPullDays));
  }

  static DateTime cloudActivityPullRangeEnd() {
    return DateTime.now().add(const Duration(days: 1));
  }
}
