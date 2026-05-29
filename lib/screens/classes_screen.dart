import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/enroll_class_dialog.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  Future<void> _showEnrollDialog(BuildContext context) async {
    final joined = await EnrollClassDialog.show(context);
    if (!context.mounted || joined != true) return;

    final app = context.read<AppState>();
    final lang = app.language;
    app.notifyEnrolledClassesChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.classEnrolled(lang))),
    );
  }

  Future<void> _confirmLeaveClass(
    BuildContext context, {
    required String className,
    required int classId,
  }) async {
    final app = context.read<AppState>();
    final lang = app.language;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.leaveClassConfirm(lang, className)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.leaveClass(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final err = await app.leaveClass(classId);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    app.notifyEnrolledClassesChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.leftClass(lang))),
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
      body: Stack(
        children: [
          ListView(
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
                ...classes.map((enrolled) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          enrolled.className,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                      ),
                      PanelCard(
                        margin: const EdgeInsets.only(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${AppStrings.teacherLabel(lang)}: ${enrolled.teacherName}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.textMain.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _confirmLeaveClass(
                                  context,
                                  className: enrolled.className,
                                  classId: enrolled.classId,
                                ),
                                child: Text(
                                  AppStrings.leaveClass(lang),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.bgAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
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
