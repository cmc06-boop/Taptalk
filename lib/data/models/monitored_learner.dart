import 'linked_child_model.dart';
import 'teacher_class_student.dart';

/// Learner shown on parent or teacher monitoring (charts & phrase stats).
class MonitoredLearner {
  const MonitoredLearner({
    required this.learnerId,
    required this.fullName,
    required this.trackingSince,
    this.contextSubtitle,
  });

  final int learnerId;
  final String fullName;
  /// Earliest date for month picker range (link or class enrollment).
  final DateTime trackingSince;
  final String? contextSubtitle;

  factory MonitoredLearner.fromLinkedChild(LinkedChildModel child) {
    return MonitoredLearner(
      learnerId: child.learnerId,
      fullName: child.fullName,
      trackingSince: child.linkedAt,
    );
  }

  factory MonitoredLearner.fromTeacherStudent(TeacherClassStudent student) {
    return MonitoredLearner(
      learnerId: student.learnerId,
      fullName: student.fullName,
      trackingSince: student.enrolledAt,
      contextSubtitle: student.className,
    );
  }
}
