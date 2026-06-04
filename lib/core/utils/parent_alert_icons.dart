import 'package:flutter/material.dart';

import '../../data/models/parent_notification.dart';

/// Icons and subtle accents aligned to each parent alert type.
abstract final class ParentAlertIcons {
  static IconData forType(ParentAlertType type) => switch (type) {
        ParentAlertType.needsAttention => Icons.priority_high_rounded,
        ParentAlertType.distress => Icons.mood_bad_outlined,
        ParentAlertType.schoolNeeded => Icons.school_outlined,
        ParentAlertType.teacherAlert => Icons.campaign_outlined,
      };

  static Color iconColor(ParentAlertType type) => switch (type) {
        ParentAlertType.needsAttention => const Color(0xFFC62828),
        ParentAlertType.distress => const Color(0xFFE65100),
        ParentAlertType.schoolNeeded => const Color(0xFF1565C0),
        ParentAlertType.teacherAlert => const Color(0xFF546E7A),
      };

  static Color iconBackground(ParentAlertType type) => switch (type) {
        ParentAlertType.needsAttention => const Color(0xFFFFEBEE),
        ParentAlertType.distress => const Color(0xFFFFF3E0),
        ParentAlertType.schoolNeeded => const Color(0xFFE3F2FD),
        ParentAlertType.teacherAlert => const Color(0xFFECEFF1),
      };
}
