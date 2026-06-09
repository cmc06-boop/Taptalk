import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/enrolled_class_model.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
import '../widgets/enroll_class_dialog.dart';
import '../widgets/taptalk_result_dialog.dart';
import '../widgets/learner_scaffold.dart';
import 'learner_class_detail_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  Future<void> _showEnrollDialog(BuildContext context) async {
    final joined = await EnrollClassDialog.show(context);
    if (!context.mounted || joined != true) return;

    final app = context.read<AppState>();
    final lang = app.language;
    app.notifyEnrolledClassesChanged();
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.classEnrolledTitle(lang),
      message: AppStrings.classEnrolled(lang),
    );
  }

  Future<void> _confirmUnenroll(
    BuildContext context, {
    required String className,
    required int classId,
  }) async {
    final app = context.read<AppState>();
    final lang = app.language;

    final displayClassName = app.localizedContent(className);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.unenrollConfirm(lang, displayClassName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.unenroll(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final err = await app.leaveClass(classId);
    if (!context.mounted) return;
    if (err != null) {
      await TapTalkResultDialog.showError(
        context,
        title: AppStrings.somethingWentWrong(lang),
        message: err,
      );
      return;
    }
    app.notifyEnrolledClassesChanged();
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.leftClassTitle(lang),
      message: AppStrings.leftClass(lang),
    );
  }

  Future<void> _onRefresh() async {
    await context.read<AppState>().refreshEnrolledClasses();
  }

  void _openClass(BuildContext context, EnrolledClassModel enrolled) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearnerClassDetailScreen(
          enrolledClass: enrolled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final classes = app.enrolledClasses;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.classes,
      showBottomNav: false,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
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
                        AppStrings.classes(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.classesSubtitle(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.textMain.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (classes.isEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.35,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        AppStrings.noEnrolledClasses(lang),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: theme.textMain.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                )
              else
                for (final enrolled in classes)
                  Padding(
                    key: ValueKey(
                      'class_${enrolled.classId}_${lang.name}_${app.languageRevision}',
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: ClassColorCard(
                      classId: enrolled.classId,
                      title: enrolled.className,
                      subtitle: enrolled.teacherName,
                      onTap: () => _openClass(context, enrolled),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        onSelected: (value) {
                          if (value == 'unenroll') {
                            _confirmUnenroll(
                              context,
                              className: enrolled.className,
                              classId: enrolled.classId,
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'unenroll',
                            child: Text(
                              AppStrings.unenroll(lang),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          ), // end RefreshIndicator
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              onPressed: () => _showEnrollDialog(context),
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              tooltip: AppStrings.joinClass(lang),
              child: const Icon(Icons.group_add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
