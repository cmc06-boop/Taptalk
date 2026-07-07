abstract final class MonitoringConstants {
  /// Phrases must be used at least this many times to appear as "frequently used".
  static const int frequentlyUsedMinCount = 5;

  /// Gap between phrase taps before a new usage session starts.
  static const Duration sessionGap = Duration(minutes: 15);

  /// History rows within this window with the same phrase are treated as one tap.
  static const Duration monitoringHistoryDedupeWindow = Duration(seconds: 5);

  /// How far back parent/teacher cloud pulls reach for learner phrase activity.
  static const int cloudActivityPullDays = 365 * 3;

  /// How often an open monitoring screen polls for fresh learner activity.
  static const Duration monitoringPollInterval = Duration(seconds: 12);

  /// How often a learner device retries uploading queued offline activity.
  static const Duration pendingActivitySyncInterval = Duration(seconds: 45);

  /// Cloud pull timeout for a full monitoring refresh.
  static const Duration monitoringPullTimeout = Duration(seconds: 18);

  /// Cloud pull timeout for incremental activity-only refresh.
  static const Duration monitoringIncrementalPullTimeout = Duration(seconds: 8);

  /// Minimum lookback for incremental pulls so brief sync gaps are not missed.
  static const Duration monitoringIncrementalLookback = Duration(hours: 24);

  static DateTime cloudActivityPullRangeStart() {
    return DateTime.now().subtract(const Duration(days: cloudActivityPullDays));
  }

  static DateTime cloudActivityPullRangeEnd() {
    return DateTime.now().add(const Duration(days: 1));
  }
}
