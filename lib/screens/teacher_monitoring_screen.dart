import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/navigation/route_transitions.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/class_color_card.dart';
import '../widgets/learner_scaffold.dart';
import 'teacher_class_monitoring_screen.dart';

class TeacherMonitoringScreen extends StatefulWidget {
  const TeacherMonitoringScreen({super.key});

  @override
  State<TeacherMonitoringScreen> createState() => _TeacherMonitoringScreenState();
}

class _TeacherMonitoringScreenState extends State<TeacherMonitoringScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      if (app.teacherClasses.isEmpty) {
        await app.refreshTeacherClasses(cloudSyncInBackground: true);
      }
    });
  }

  Future<void> _refreshFromCloud() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AppState>().refreshTeacherClasses(
            cloudSyncInBackground: false,
          );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openClass(({int id, String name, String code}) teacherClass) {
    Navigator.of(context)
        .push(
          taptalkPageRoute<void>(
            builder: (_) => TeacherClassMonitoringScreen(
              classId: teacherClass.id,
              className: teacherClass.name,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          context.read<AppState>().refreshTeacherClasses(
                cloudSyncInBackground: true,
              );
        });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final classes = app.teacherClasses;

    return LearnerScaffold(
      title: AppStrings.monitoring(lang),
      titleWidget: AppHeaderTitle(AppStrings.monitoring(lang)),
      currentRoute: AppRoute.teacherMonitoring,
      headerContentHeight: AppHeaderTitle.height,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      showBottomNav: false,
      body: RefreshIndicator(
        onRefresh: _refreshFromCloud,
        child: classes.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            child: Text(
                              AppStrings.noTeacherClasses(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: theme.textMain.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            for (final teacherClass in classes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ClassColorCard(
                    classId: teacherClass.id,
                    title: teacherClass.name,
                    badge: teacherClass.code,
                    subtitle: AppStrings.studentsInClass(
                      app.teacherClassStudentCount(teacherClass.id),
                      lang,
                    ),
                    icon: Icons.monitor_heart_outlined,
                    onTap: () => _openClass(teacherClass),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
