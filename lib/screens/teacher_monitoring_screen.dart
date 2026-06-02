import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import 'teacher_class_monitoring_screen.dart';

class TeacherMonitoringScreen extends StatefulWidget {
  const TeacherMonitoringScreen({super.key});

  @override
  State<TeacherMonitoringScreen> createState() => _TeacherMonitoringScreenState();
}

class _TeacherMonitoringScreenState extends State<TeacherMonitoringScreen> {
  final Map<int, int> _studentCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final counts = <int, int>{};
    for (final teacherClass in app.teacherClasses) {
      counts[teacherClass.id] = await app.studentCountForClass(teacherClass.id);
    }
    if (!mounted) return;
    setState(() {
      _studentCounts
        ..clear()
        ..addAll(counts);
      _loading = false;
    });
  }

  void _openClass(({int id, String name, String code}) teacherClass) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TeacherClassMonitoringScreen(
              classId: teacherClass.id,
              className: teacherClass.name,
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final classes = app.teacherClasses;

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
          else if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  AppStrings.noTeacherClasses(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: theme.textMain.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            for (final teacherClass in classes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MonitoringClassCard(
                  className: teacherClass.name,
                  studentCount: _studentCounts[teacherClass.id] ?? 0,
                  theme: theme,
                  lang: lang,
                  onTap: () => _openClass(teacherClass),
                ),
              ),
        ],
      ),
    );
  }
}

class _MonitoringClassCard extends StatelessWidget {
  const _MonitoringClassCard({
    required this.className,
    required this.studentCount,
    required this.theme,
    required this.lang,
    required this.onTap,
  });

  final String className;
  final int studentCount;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.bgAccent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_rounded, color: accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.studentsInClass(studentCount, lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textMain.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
