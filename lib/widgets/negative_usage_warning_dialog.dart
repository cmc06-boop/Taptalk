import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/teacher_negative_usage_warning.dart';
import 'taptalk_result_dialog.dart';

Future<void> showNegativeUsageWarningDialog(
  BuildContext context, {
  required List<TeacherNegativeUsageWarning> warnings,
  required AppLanguage lang,
}) {
  if (warnings.isEmpty) return Future<void>.value();
  final grouped = <String, List<TeacherNegativeUsageWarning>>{};
  for (final warning in warnings) {
    grouped.putIfAbsent(warning.childName, () => []).add(warning);
  }
  final buffer = StringBuffer();
  for (final entry in grouped.entries) {
    if (buffer.isNotEmpty) buffer.writeln();
    for (final warning in entry.value) {
      buffer.writeln(
        AppStrings.negativeUsageWarningBody(
          lang,
          warning.childName,
          warning.phraseText,
          warning.count,
        ),
      );
    }
  }

  return TapTalkResultDialog.show(
    context,
    success: false,
    title: AppStrings.negativeUsageWarningTitle(lang),
    message: buffer.toString().trim(),
  );
}
