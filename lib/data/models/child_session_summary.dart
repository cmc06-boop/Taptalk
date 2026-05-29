class SessionUsageBucket {
  const SessionUsageBucket({
    required this.label,
    required this.minutes,
    this.isActive = false,
  });

  final String label;
  final double minutes;
  final bool isActive;
}

class ChildSessionSummary {
  const ChildSessionSummary({
    required this.totalMinutes,
    required this.sessionCount,
    required this.buckets,
    required this.chartPeakMinutes,
    this.hasActiveSession = false,
    this.liveSessionMinutes = 0,
    this.activeHourIndex,
  });

  final double totalMinutes;
  final int sessionCount;
  final List<SessionUsageBucket> buckets;
  final double chartPeakMinutes;
  final bool hasActiveSession;
  final double liveSessionMinutes;
  final int? activeHourIndex;

  double get averageSessionMinutes =>
      sessionCount == 0 ? 0 : totalMinutes / sessionCount;

  static const empty = ChildSessionSummary(
    totalMinutes: 0,
    sessionCount: 0,
    buckets: [],
    chartPeakMinutes: 1,
  );
}
