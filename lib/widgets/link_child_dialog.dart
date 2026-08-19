import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import 'code_scan_flow_screen.dart';
import 'taptalk_result_dialog.dart';

/// Parent links a learner — opens scan-first flow with manual entry fallback.
class LinkChildDialog {
  LinkChildDialog._();

  /// Returns `true` after a successful link, or null if cancelled.
  static Future<bool?> show(BuildContext context) async {
    final app = context.read<AppState>();
    final lang = app.language;

    final linked = await CodeScanFlowScreen.open(
      context,
      kind: QrScanKind.profileCode,
      title: AppStrings.linkChildCode(lang),
      scanHint: AppStrings.qrScanProfileHint(lang),
      manualTitle: AppStrings.linkChildCode(lang),
      manualHint: AppStrings.enterChildCodeHint(lang),
      manualHintText: 'TT-XXXXXXXX',
      onSubmit: app.linkChildByProfileCode,
    );

    if (!context.mounted || !linked) return linked ? true : null;

    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.childLinkedTitle(lang),
      message: AppStrings.childLinked(lang),
    );
    return true;
  }
}
