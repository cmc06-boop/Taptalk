import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Schedules [reload] once when [currentRevision] changes.
int bindLiveRevision({
  required int lastRevision,
  required int currentRevision,
  required Future<void> Function() reload,
  required bool Function() isMounted,
}) {
  if (currentRevision == lastRevision) return lastRevision;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (isMounted()) unawaited(reload());
  });
  return currentRevision;
}

/// Combines global live revision with an optional per-class content revision.
int bindCombinedLiveRevision({
  required int lastGlobalRevision,
  required int lastClassRevision,
  required int globalRevision,
  required int classRevision,
  required Future<void> Function() reload,
  required bool Function() isMounted,
}) {
  if (globalRevision == lastGlobalRevision &&
      classRevision == lastClassRevision) {
    return lastGlobalRevision;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (isMounted()) unawaited(reload());
  });
  return globalRevision;
}

int latestClassRevision({
  required int lastClassRevision,
  required int classRevision,
}) {
  return classRevision != lastClassRevision ? classRevision : lastClassRevision;
}

/// Schedules [reload] once when a class's own content revision changes.
int bindClassContentRevision({
  required int lastClassRevision,
  required int classRevision,
  required Future<void> Function() reload,
  required bool Function() isMounted,
}) {
  if (classRevision == lastClassRevision) return lastClassRevision;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (isMounted()) unawaited(reload());
  });
  return classRevision;
}
