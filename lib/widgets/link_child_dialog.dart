import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/code_qr_utils.dart';
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
    var receivedTransfer = false;

    final linked = await CodeScanFlowScreen.open(
      context,
      kind: QrScanKind.caregiverCode,
      title: AppStrings.scanChildOrTransfer(lang),
      scanHint: AppStrings.scanChildOrTransferHint(lang),
      manualTitle: AppStrings.scanChildOrTransfer(lang),
      manualHint: AppStrings.enterChildOrTransferCode(lang),
      manualHintText: 'TT-XXXXXXXX / TR-XXXXXXXX',
      onSubmit: (code) {
        receivedTransfer = CodeQrUtils.extractTransferCode(code) != null;
        return receivedTransfer
            ? app.receiveCaregiverTransfer(code)
            : app.linkChildByProfileCode(code);
      },
    );

    if (!context.mounted || !linked) return linked ? true : null;

    await TapTalkResultDialog.showSuccess(
      context,
      title: receivedTransfer
          ? AppStrings.learnerTransferredTitle(lang)
          : AppStrings.childLinkedTitle(lang),
      message: receivedTransfer
          ? AppStrings.transferReceivedBody(lang)
          : AppStrings.childLinked(lang),
    );
    return true;
  }
}
