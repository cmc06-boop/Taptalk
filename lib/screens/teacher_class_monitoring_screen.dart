import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/monitored_learner.dart';
import '../data/models/parent_notification.dart';
import '../data/models/teacher_class_student.dart';
import '../providers/app_state.dart';
import '../core/utils/parent_alert_icons.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/student_count_badge.dart';
import '../widgets/taptalk_result_dialog.dart';
import 'child_monitoring_screen.dart';

class _TeacherAlertSelection {
  const _TeacherAlertSelection.preset(this.alertType) : customMessage = null;

  const _TeacherAlertSelection.custom(this.customMessage)
      : alertType = ParentAlertType.teacherAlert;

  final ParentAlertType alertType;
  final String? customMessage;

  bool get isCustom => customMessage != null;
}

class TeacherClassMonitoringScreen extends StatefulWidget {
  const TeacherClassMonitoringScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final int classId;
  final String className;

  @override
  State<TeacherClassMonitoringScreen> createState() =>
      _TeacherClassMonitoringScreenState();
}

class _TeacherClassMonitoringScreenState
    extends State<TeacherClassMonitoringScreen> {
  List<TeacherClassStudent> _students = [];
  bool _refreshing = false;

  bool _sameStudents(List<TeacherClassStudent> a, List<TeacherClassStudent> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].learnerId != b[i].learnerId ||
          a[i].fullName != b[i].fullName) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents({bool userRefresh = false}) async {
    final app = context.read<AppState>();
    if (userRefresh) {
      if (_refreshing) return;
      setState(() => _refreshing = true);
    }
    try {
      final students = await app.getTeacherClassStudentsForClass(
        widget.classId,
        cloudSyncInBackground: !userRefresh,
      );
      if (!mounted) return;
      if (_sameStudents(_students, students)) return;
      setState(() => _students = students);
    } catch (e, st) {
      debugPrint('Teacher class roster load failed: $e\n$st');
    } finally {
      if (mounted && _refreshing) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _onRefresh() => _loadStudents(userRefresh: true);

  void _openMonitoring(TeacherClassStudent student) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildMonitoringScreen(
          learner: MonitoredLearner.fromTeacherStudent(student),
          currentRoute: AppRoute.teacherMonitoring,
        ),
      ),
    );
  }

  Future<String?> _promptCustomAlertMessage(
    AppLanguage lang,
    TapTalkThemeToken theme,
  ) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          AppStrings.customAlertMessageTitle(lang),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 140,
          decoration: InputDecoration(
            hintText: AppStrings.customAlertMessageHint(lang),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.bgAccent, width: 1.5),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppStrings.customAlertMessageEmpty(lang))),
                );
                return;
              }
              Navigator.pop(ctx, text);
            },
            style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
            child: Text(AppStrings.ok(lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSendAlert(TeacherClassStudent student) async {
    final app = context.read<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final selected = await showModalBottomSheet<_TeacherAlertSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7EDF2)),
            boxShadow: [
              BoxShadow(
                color: theme.textMain.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.chooseAlertType(lang),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.textMain,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final type in ParentAlertType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          Navigator.pop(ctx, _TeacherAlertSelection.preset(type)),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: theme.bgMid.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              ParentAlertIcons.forType(type),
                              size: 18,
                              color: theme.bgAccent,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                AppStrings.alertTypeLabel(lang, type),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textMain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(
                      ctx,
                      const _TeacherAlertSelection.custom(''),
                    ),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.bgAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.bgAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: theme.bgAccent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              AppStrings.writeCustomAlertMessage(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.textMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppStrings.cancel(lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    String? customMessage;
    if (selected.isCustom) {
      customMessage = await _promptCustomAlertMessage(lang, theme);
      if (customMessage == null || customMessage.trim().isEmpty || !mounted) {
        return;
      }
      customMessage = customMessage.trim();
    }

    final alertPreview =
        customMessage ?? AppStrings.alertTypeLabel(lang, selected.alertType);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFC62828),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    AppStrings.alertStudent(lang),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${AppStrings.alertStudentConfirm(lang, student.fullName)}\n\n$alertPreview',
              style: GoogleFonts.poppins(height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: Text(AppStrings.alertStudent(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final delivery = await app.sendTeacherAlert(
      learnerUserId: student.learnerId,
      learnerName: student.fullName,
      classId: widget.classId,
      className: widget.className,
      alertType: selected.alertType,
      customMessage: customMessage,
    );
    if (!mounted) return;

    final smsOk =
        delivery.sms.errorMessage == null && delivery.sms.sent > 0;
    final success = delivery.inAppSent || smsOk;
    final smsError = delivery.sms.errorMessage;
    final smsSummary = smsError != null
        ? 'SMS: $smsError'
        : delivery.sms.openedComposer
            ? AppStrings.smsTapSendToDeliver(lang)
            : AppStrings.smsSentViaPhone(
                lang,
                delivery.sms.sent,
                delivery.sms.attempted,
              );
    final resultMessage = delivery.inAppError == null
        ? '${AppStrings.alertSent(lang, student.fullName)}\n$smsSummary'
        : '${delivery.inAppError}\n$smsSummary';
    await TapTalkResultDialog.show(
      context,
      success: success,
      title: success
          ? AppStrings.alertSentTitle(lang)
          : AppStrings.alertFailedTitle(lang),
      message: resultMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final displayClassName = app.localizedContent(widget.className);

    return LearnerScaffold(
      title: displayClassName,
      titleBadge: StudentCountBadge(
        count: _students.length,
        accent: theme.bgAccent,
      ),
      currentRoute: AppRoute.teacherMonitoring,
      showBackButton: true,
      showBottomNav: false,
      onBack: () => Navigator.of(context).pop(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (_refreshing && _students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_students.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  AppStrings.noTeacherStudents(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: theme.textMain.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            for (final student in _students)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _StudentMonitoringTile(
                  student: student,
                  theme: theme,
                  lang: lang,
                  onOpen: () => _openMonitoring(student),
                  onAlert: () => _confirmAndSendAlert(student),
                ),
              ),
        ],
        ),
      ),
    );
  }
}

class _StudentMonitoringTile extends StatelessWidget {
  const _StudentMonitoringTile({
    required this.student,
    required this.theme,
    required this.lang,
    required this.onOpen,
    required this.onAlert,
  });

  final TeacherClassStudent student;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onOpen;
  final VoidCallback onAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF2)),
        boxShadow: [
          BoxShadow(
            color: theme.textMain.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.bgAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: theme.bgAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.fullName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.viewMonitoring(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.bgAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: onAlert,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFEBEE),
                foregroundColor: const Color(0xFFC62828),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(
                AppStrings.alertStudent(lang),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
