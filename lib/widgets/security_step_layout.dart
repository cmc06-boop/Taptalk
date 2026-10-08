import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../providers/app_state.dart';
import 'taptalk_shell.dart';

/// Security steps share the look of the app's bottom-sheet code modals: a
/// large icon on the tinted background and a rounded sheet with the action.
class SecurityStepLayout extends StatelessWidget {
  const SecurityStepLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.children = const [],
    this.message,
    this.messageIsError = false,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondary,
    this.footerLabel,
    this.onFooter,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? message;
  final bool messageIsError;
  final bool busy;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? footerLabel;
  final VoidCallback? onFooter;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final padding = MediaQuery.paddingOf(context);
    final muted = theme.textMain.withValues(alpha: 0.65);

    final sheet = Container(
      decoration: BoxDecoration(
        color: theme.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: theme.textMain.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md + padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.textMain.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.textMain,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.35,
              color: muted,
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: messageIsError ? const Color(0xFFC62828) : muted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: busy ? null : onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: theme.bgAccent.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    primaryLabel,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
          if (secondaryLabel != null || footerLabel != null)
            Row(
              mainAxisAlignment: secondaryLabel != null && footerLabel != null
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (secondaryLabel != null)
                  TextButton(
                    onPressed: busy ? null : onSecondary,
                    child: Text(
                      secondaryLabel!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.bgAccent,
                      ),
                    ),
                  ),
                if (footerLabel != null)
                  TextButton(
                    onPressed: busy ? null : onFooter,
                    child: Text(
                      footerLabel!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    return TapTalkShell(
      backgroundColor: Color.alphaBlend(
        theme.bgAccent.withValues(alpha: 0.12),
        theme.bgLight,
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: padding.top),
              child: Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.textMain.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 44, color: theme.bgAccent),
                ),
              ),
            ),
          ),
          sheet,
        ],
      ),
    );
  }
}

/// Text field styled like the code entry sheet.
class SecurityStepField extends StatelessWidget {
  const SecurityStepField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.bgAccent.withValues(alpha: 0.75),
            width: 1.6,
          ),
        ),
      ),
    );
  }
}
