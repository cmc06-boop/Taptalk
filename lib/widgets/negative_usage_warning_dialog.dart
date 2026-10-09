import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/constants/monitoring_constants.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/parent_alert_icons.dart';
import '../data/models/parent_notification.dart';
import '../data/models/teacher_negative_usage_warning.dart';
import '../providers/app_state.dart';

const _warningFeedback = MethodChannel('com.taptalk/warning_feedback');

Future<void> showNegativeUsageWarningDialog(
  BuildContext context, {
  required List<TeacherNegativeUsageWarning> warnings,
  required AppLanguage lang,
  bool emphasizeTypeLabel = false,
}) async {
  if (warnings.isEmpty) return;
  final theme = context.read<AppState>().theme;
  for (final warning in warnings) {
    if (!context.mounted) return;
    unawaited(
      _warningFeedback
          .invokeMethod<void>('play', const {'durationMs': 3000})
          .catchError((Object _) {}),
    );
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: theme.textMain.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final alertType = ParentNotification.alertTypeFromKey(
          MonitoringConstants.negativeUsageAlertType,
        );
        final levelTitle = warning.title.isNotEmpty
            ? warning.title
            : AppStrings.negativeUsageWarningLevelTitle(lang, warning.level);
        final childName = warning.childName.trim();
        return Center(
          child: _NegativeUsageWarningPopup(
            title: emphasizeTypeLabel && childName.isNotEmpty
                ? childName
                : levelTitle,
            typeLabel: emphasizeTypeLabel ? levelTitle : null,
            body: _firstParagraph(
              warning.body.isNotEmpty
                  ? warning.body
                  : AppStrings.negativeUsageWarningNotificationBody(
                      lang,
                      warning.childName,
                      warning.phraseText,
                      warning.count,
                      warning.level,
                    ),
            ),
            theme: theme,
            lang: lang,
            timeLabel: DateFormat.jm(
              lang == AppLanguage.filipino ? 'fil_PH' : 'en_US',
            ).format(DateTime.now()),
            alertType: alertType,
            icon: ParentAlertIcons.forType(alertType),
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

String _firstParagraph(String body) {
  var text = body.trim().split(RegExp(r'\n\s*\n')).first.trim();
  text = text.replaceAll(
    RegExp(
      r'\s*(This phrase has reached the daily attention threshold\.?'
      r'|This phrase reached the attention threshold[^\n]*'
      r'|Naabot ng pariralang ito ang arawang attention threshold\.?'
      r'|Naabot ulit ng pariralang ito[^\n]*'
      r'|Naabot ng pariralang ito ang attention threshold sa loob[^\n]*)',
      caseSensitive: false,
    ),
    '',
  );
  return text.trim();
}

class _NegativeUsageWarningPopup extends StatelessWidget {
  const _NegativeUsageWarningPopup({
    required this.title,
    required this.body,
    required this.theme,
    required this.lang,
    required this.timeLabel,
    required this.alertType,
    required this.icon,
    required this.onClose,
    this.typeLabel,
  });

  final String title;
  final String body;
  final String? typeLabel;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String timeLabel;
  final ParentAlertType alertType;
  final IconData icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = theme.bgAccent;
    final iconColor = ParentAlertIcons.iconColor(alertType);
    final iconBg = ParentAlertIcons.iconBackground(alertType);
    final label = typeLabel?.trim() ?? '';
    final showTypeLabel = label.isNotEmpty;
    final showHeadline =
        title.trim().isNotEmpty &&
        title.trim().toLowerCase() != label.toLowerCase();
    final trimmedBody = body.trim();
    final showBody =
        trimmedBody.isNotEmpty &&
        trimmedBody.toLowerCase() != label.toLowerCase();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9EEF2)),
              boxShadow: [
                BoxShadow(
                  color: theme.textMain.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 24, color: iconColor),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeadline)
                                Text(
                                  title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textMain,
                                    height: 1.25,
                                  ),
                                ),
                              if (showHeadline) const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textMain.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.textMain.withValues(alpha: 0.45),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showTypeLabel) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else
                    const SizedBox(height: AppSpacing.md),
                  if (showBody)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Text(
                          body,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.textMain.withValues(alpha: 0.82),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: FilledButton(
                      onPressed: onClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppStrings.ok(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
