import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../providers/app_state.dart';
import 'taptalk_shell.dart';

/// Centered security card used by phone verification and identity confirmation.
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
    this.showPrimary = true,
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
  final bool showPrimary;
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 430;
    final muted = theme.textMain.withValues(alpha: 0.62);
    final cardFill = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.78),
      theme.bgLight,
    );

    return TapTalkShell(
      backgroundColor: theme.bgLight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.15,
            colors: [theme.bgMid.withValues(alpha: 0.72), theme.bgLight],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? AppSpacing.xl : AppSpacing.xxl,
                AppSpacing.lg,
                compact ? AppSpacing.xl : AppSpacing.xxl,
                AppSpacing.lg + padding.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight -
                      AppSpacing.lg * 2 -
                      padding.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        compact ? AppSpacing.lg : AppSpacing.xxl,
                        compact ? AppSpacing.xl : AppSpacing.xxl,
                        compact ? AppSpacing.lg : AppSpacing.xxl,
                        compact ? AppSpacing.lg : AppSpacing.xl,
                      ),
                      decoration: BoxDecoration(
                        color: cardFill,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.bgAccent.withValues(alpha: 0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: compact ? 64 : 72,
                              height: compact ? 64 : 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.textMain.withValues(
                                      alpha: 0.06,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: compact ? 30 : 34,
                                color: theme.bgAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: theme.textMain,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                              color: muted,
                            ),
                          ),
                          if (children.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            ...children,
                          ],
                          if (message != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              message!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: messageIsError
                                    ? const Color(0xFFC62828)
                                    : muted,
                              ),
                            ),
                          ],
                          if (showPrimary) ...[
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton(
                              onPressed: busy ? null : onPrimary,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.bgAccent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: theme.bgAccent
                                    .withValues(alpha: 0.48),
                                disabledForegroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
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
                          ] else
                            const SizedBox(height: AppSpacing.md),
                          if (secondaryLabel != null)
                            if (onSecondary == null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  secondaryLabel!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: muted,
                                  ),
                                ),
                              )
                            else
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
                          if (footerLabel != null) ...[
                            const SizedBox(height: AppSpacing.sm),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Password field from the identity-check card, including lock and visibility.
class SecurityStepField extends StatefulWidget {
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
  State<SecurityStepField> createState() => _SecurityStepFieldState();
}

class _SecurityStepFieldState extends State<SecurityStepField> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: theme.textMain.withValues(alpha: 0.12),
        width: 1.2,
      ),
    );
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: theme.textMain,
      ),
      decoration: InputDecoration(
        hintText: widget.label,
        hintStyle: GoogleFonts.poppins(
          fontSize: 15,
          color: theme.textMain.withValues(alpha: 0.56),
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 21,
          color: theme.textMain.withValues(alpha: 0.58),
        ),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _hidden = !_hidden),
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 21,
                  color: theme.textMain.withValues(alpha: 0.58),
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
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
