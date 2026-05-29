import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/monitored_learner.dart';
import '../data/models/teacher_class_student.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import 'child_monitoring_screen.dart';

class TeacherMonitoringScreen extends StatefulWidget {
  const TeacherMonitoringScreen({super.key});

  @override
  State<TeacherMonitoringScreen> createState() => _TeacherMonitoringScreenState();
}

class _TeacherMonitoringScreenState extends State<TeacherMonitoringScreen> {
  List<TeacherClassStudent> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students =
        await context.read<AppState>().getTeacherClassStudents();
    if (!mounted) return;
    setState(() {
      _students = students;
      _loading = false;
    });
  }

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

  void _onAlertTap(AppLanguage lang) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.alertStudentSoon(lang))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.teacherMonitoring,
      showBottomNav: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.bgMid.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.monitoring(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.teacherMonitoringSubtitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
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
                  onAlert: () => _onAlertTap(lang),
                ),
              ),
        ],
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
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
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
                            AppStrings.enrolledIn(lang, student.className),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: theme.textMain.withValues(alpha: 0.62),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.textMain.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: theme.textMain.withValues(alpha: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
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
            ),
          ),
        ],
      ),
    );
  }
}
