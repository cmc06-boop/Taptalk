import 'package:intl/intl.dart';

import '../constants/child_usage_period.dart';
import '../../data/models/child_session_summary.dart';

/// Infers TapTalk usage sessions from phrase history timestamps.
abstract final class SessionUsageCalculator {
  static const _sessionGap = Duration(minutes: 15);
  static const _minSession = Duration(minutes: 2);
  static const _phraseTail = Duration(seconds: 45);

  static ChildSessionSummary summarize({
    required List<DateTime> events,
    required ChildUsagePeriod period,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String localeName,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (events.isEmpty) return ChildSessionSummary.empty;

    final sessions = _clusterSessions(events);
    final hasActiveSession = clock.difference(events.last) <= _sessionGap;

    final durations = <Duration>[];
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      final isLast = i == sessions.length - 1;
      final end = isLast && hasActiveSession ? clock : session.end;
      durations.add(_sessionDuration((start: session.start, end: end)));
    }

    final totalMinutes =
        durations.fold<double>(0, (sum, d) => sum + d.inSeconds / 60.0);

    final liveSessionMinutes = hasActiveSession
        ? durations.last.inSeconds / 60.0
        : 0.0;

    int? activeHourIndex;
    if (hasActiveSession && period == ChildUsagePeriod.today) {
      final dayStart = DateTime(clock.year, clock.month, clock.day);
      activeHourIndex = clock.difference(dayStart).inHours.clamp(0, 23);
    }

    final buckets = switch (period) {
      ChildUsagePeriod.today => _bucketByHour(
          sessions,
          rangeStart,
          clock,
          hasActiveSession: hasActiveSession,
          activeHourIndex: activeHourIndex,
        ),
      ChildUsagePeriod.thisWeek => _bucketByDay(
          sessions,
          durations,
          rangeStart,
          rangeEnd,
          localeName,
          dayCount: 7,
          clock: clock,
          hasActiveSession: hasActiveSession,
        ),
      ChildUsagePeriod.month => _bucketMonth(
          sessions,
          durations,
          rangeStart,
          rangeEnd,
          localeName,
          clock: clock,
          hasActiveSession: hasActiveSession,
        ),
    };

    final peak = buckets.fold<double>(
      1,
      (max, b) => b.minutes > max ? b.minutes : max,
    );

    return ChildSessionSummary(
      totalMinutes: totalMinutes,
      sessionCount: sessions.length,
      buckets: buckets,
      chartPeakMinutes: peak,
      hasActiveSession: hasActiveSession,
      liveSessionMinutes: liveSessionMinutes,
      activeHourIndex: activeHourIndex,
    );
  }

  static List<({DateTime start, DateTime end})> _clusterSessions(
    List<DateTime> events,
  ) {
    final sorted = [...events]..sort();
    final sessions = <({DateTime start, DateTime end})>[];
    var start = sorted.first;
    var end = sorted.first;

    for (var i = 1; i < sorted.length; i++) {
      final t = sorted[i];
      if (t.difference(end) > _sessionGap) {
        sessions.add((start: start, end: end));
        start = t;
        end = t;
      } else {
        end = t;
      }
    }
    sessions.add((start: start, end: end));
    return sessions;
  }

  static Duration _sessionDuration(({DateTime start, DateTime end}) session) {
    final span = session.end.difference(session.start) + _phraseTail;
    return span < _minSession ? _minSession : span;
  }

  static String hourLabelAmPm(int hour) {
    final h = hour % 24;
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  static void _distributeMinutesAcrossHours(
    List<double> values,
    DateTime start,
    DateTime end,
    DateTime dayStart,
  ) {
    if (!end.isAfter(start)) return;

    var cursor = start.isBefore(dayStart) ? dayStart : start;
    final dayEnd = dayStart.add(const Duration(days: 1));
    final cappedEnd = end.isAfter(dayEnd) ? dayEnd : end;

    while (cursor.isBefore(cappedEnd)) {
      final hourIndex = cursor.difference(dayStart).inHours;
      if (hourIndex < 0 || hourIndex > 23) break;

      final nextHour = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour)
          .add(const Duration(hours: 1));
      final sliceEnd = cappedEnd.isBefore(nextHour) ? cappedEnd : nextHour;
      values[hourIndex] += sliceEnd.difference(cursor).inSeconds / 60.0;
      cursor = sliceEnd;
    }
  }

  static List<SessionUsageBucket> _bucketByHour(
    List<({DateTime start, DateTime end})> sessions,
    DateTime day,
    DateTime clock, {
    required bool hasActiveSession,
    required int? activeHourIndex,
  }) {
    final values = List<double>.filled(24, 0);
    final dayStart = DateTime(day.year, day.month, day.day);

    for (var i = 0; i < sessions.length; i++) {
      final isLast = i == sessions.length - 1;
      final end = isLast && hasActiveSession ? clock : sessions[i].end;
      _distributeMinutesAcrossHours(
        values,
        sessions[i].start,
        end,
        dayStart,
      );
    }

    return List.generate(24, (hour) {
      final showLabel = hour == 0 || hour == 6 || hour == 12 || hour == 18;
      return SessionUsageBucket(
        label: showLabel ? hourLabelAmPm(hour) : '',
        minutes: values[hour],
        isActive: activeHourIndex == hour,
      );
    });
  }

  static List<SessionUsageBucket> _bucketByDay(
    List<({DateTime start, DateTime end})> sessions,
    List<Duration> durations,
    DateTime rangeStart,
    DateTime rangeEnd,
    String localeName, {
    required int dayCount,
    required DateTime clock,
    required bool hasActiveSession,
  }) {
    final values = List<double>.filled(dayCount, 0);

    for (var i = 0; i < sessions.length; i++) {
      final minutes = durations[i].inSeconds / 60.0;
      final isLast = i == sessions.length - 1;
      var dayIndex =
          sessions[i].start.difference(rangeStart).inDays.clamp(0, dayCount - 1);
      if (isLast && hasActiveSession) {
        dayIndex = clock.difference(rangeStart).inDays.clamp(0, dayCount - 1);
      }
      values[dayIndex] += minutes;
    }

    final todayIndex = clock.difference(rangeStart).inDays.clamp(0, dayCount - 1);

    return List.generate(dayCount, (index) {
      final day = rangeStart.add(Duration(days: index));
      if (!day.isBefore(rangeEnd)) {
        return const SessionUsageBucket(label: '', minutes: 0);
      }
      return SessionUsageBucket(
        label: DateFormat('EEE', localeName).format(day),
        minutes: values[index],
        isActive: hasActiveSession && index == todayIndex,
      );
    });
  }

  static List<SessionUsageBucket> _bucketMonth(
    List<({DateTime start, DateTime end})> sessions,
    List<Duration> durations,
    DateTime rangeStart,
    DateTime rangeEnd,
    String localeName, {
    required DateTime clock,
    required bool hasActiveSession,
  }) {
    final dayCount = rangeEnd.difference(rangeStart).inDays;
    if (dayCount <= 14) {
      final values = List<double>.filled(dayCount, 0);
      final todayIndex =
          clock.difference(rangeStart).inDays.clamp(0, dayCount - 1);

      for (var i = 0; i < sessions.length; i++) {
        final minutes = durations[i].inSeconds / 60.0;
        var dayIndex =
            sessions[i].start.difference(rangeStart).inDays.clamp(0, dayCount - 1);
        if (i == sessions.length - 1 && hasActiveSession) {
          dayIndex = todayIndex;
        }
        values[dayIndex] += minutes;
      }

      return List.generate(dayCount, (index) {
        final day = rangeStart.add(Duration(days: index));
        return SessionUsageBucket(
          label: DateFormat('d', localeName).format(day),
          minutes: values[index],
          isActive: hasActiveSession && index == todayIndex,
        );
      });
    }

    final weekCount = ((dayCount + 6) / 7).ceil();
    final values = List<double>.filled(weekCount, 0);
    final currentWeek =
        clock.difference(rangeStart).inDays ~/ 7;

    for (var i = 0; i < sessions.length; i++) {
      final minutes = durations[i].inSeconds / 60.0;
      var weekIndex =
          sessions[i].start.difference(rangeStart).inDays ~/ 7;
      weekIndex = weekIndex.clamp(0, weekCount - 1);
      if (i == sessions.length - 1 && hasActiveSession) {
        weekIndex = currentWeek.clamp(0, weekCount - 1);
      }
      values[weekIndex] += minutes;
    }

    return List.generate(
      weekCount,
      (week) => SessionUsageBucket(
        label: 'W${week + 1}',
        minutes: values[week],
        isActive: hasActiveSession && week == currentWeek,
      ),
    );
  }
}
