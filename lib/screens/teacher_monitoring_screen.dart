import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
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
                child: ClassColorCard(
                  classId: teacherClass.id,
                  title: teacherClass.name,
                  badge: teacherClass.code,
                  subtitle: AppStrings.studentsInClass(
                    _studentCounts[teacherClass.id] ?? 0,
                    lang,
                  ),
                  icon: Icons.monitor_heart_outlined,
                  onTap: () => _openClass(teacherClass),
                ),
              ),
        ],
      ),
    );
  }
}
