import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import 'code_scan_flow_screen.dart';

/// Learner joins a class — opens scan-first flow with manual entry fallback.
class EnrollClassDialog {
  EnrollClassDialog._();

  /// Returns `true` after a successful enroll, or null if cancelled.
  static Future<bool?> show(BuildContext context) async {
    final app = context.read<AppState>();
    final lang = app.language;

    final joined = await CodeScanFlowScreen.open(
      context,
      kind: QrScanKind.classCode,
      title: AppStrings.enrollClassCode(lang),
      scanHint: AppStrings.qrScanClassHint(lang),
      manualTitle: AppStrings.enrollClassCode(lang),
      manualHint: AppStrings.enterClassCodeHint(lang),
      manualHintText: 'CLS-XXXXXXXX',
      onSubmit: app.enrollByClassCode,
    );

    return joined ? true : null;
  }
}
