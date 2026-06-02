import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';

/// Shared dialog chrome — link child, enroll, success, and error popups.
class TapTalkDialogShell extends StatelessWidget {
  const TapTalkDialogShell({
    super.key,
    required this.theme,
    required this.title,
    required this.message,
    this.icon,
    this.iconBackground,
    this.titleColor,
    required this.actions,
    this.content,
    this.showMessage = true,
  });

  final TapTalkThemeToken theme;
  final String title;
  final String message;
  final Widget? icon;
  final Color? iconBackground;
  final Color? titleColor;
  final List<Widget> actions;
  final Widget? content;
  final bool showMessage;

  static const sheetFill = Color(0xFFEFF8F3);
  static const fieldBorder = Color(0xFFDCECE4);
  static const titleAccent = Color(0xFF5BB88A);
  static const errorTint = Color(0xFFFFEBEE);
  static const errorIcon = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: titleColor ?? theme.textMain,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBackground ?? sheetFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: fieldBorder),
                  ),
                  child: Center(child: icon),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (content != null)
              content!
            else if (showMessage && message.isNotEmpty)
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: theme.textMain.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
      actions: actions,
    );
  }
}

/// Success / error popup — same look as link-child dialogs (mint + black OK).
class TapTalkResultDialog {
  TapTalkResultDialog._();

  static Future<void> show(
    BuildContext context, {
    required bool success,
    required String title,
    required String message,
    String? buttonLabel,
  }) {
    final lang = context.read<AppState>().language;
    final theme = context.read<AppState>().theme;
    final label = buttonLabel ?? AppStrings.ok(lang);

    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => TapTalkDialogShell(
        theme: theme,
        title: title,
        message: message,
        titleColor: success ? TapTalkDialogShell.titleAccent : theme.textMain,
        iconBackground:
            success ? TapTalkDialogShell.sheetFill : TapTalkDialogShell.errorTint,
        icon: Icon(
          success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          size: 32,
          color: success ? theme.bgAccent : TapTalkDialogShell.errorIcon,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showSuccess(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      show(context, success: true, title: title, message: message);

  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      show(context, success: false, title: title, message: message);
}
