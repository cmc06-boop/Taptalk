import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
import '../widgets/create_class_dialog.dart';
import '../widgets/edit_class_dialog.dart';
import '../widgets/taptalk_result_dialog.dart';
import '../widgets/learner_scaffold.dart';
import 'teacher_class_detail_screen.dart';

class TeacherMyClassesScreen extends StatefulWidget {
  const TeacherMyClassesScreen({super.key});

  @override
  State<TeacherMyClassesScreen> createState() => _TeacherMyClassesScreenState();
}

class _TeacherMyClassesScreenState extends State<TeacherMyClassesScreen> {
  Future<void> _refresh({bool forceCloud = false}) =>
      context.read<AppState>().refreshTeacherClasses(
            cloudSyncInBackground: !forceCloud,
          );

  Future<void> _showCreateDialog() async {
    final lang = context.read<AppState>().language;
    final created = await CreateClassDialog.show(context);
    if (!mounted || created != true) return;
    if (!mounted) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.classCreatedTitle(lang),
      message: AppStrings.classCreated(lang),
    );
  }

  Future<void> _confirmDelete(({int id, String name, String code}) teacherClass) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppStrings.deleteClass(lang),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          AppStrings.deleteClassConfirm(
            lang,
            app.localizedContent(teacherClass.name),
          ),
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
            child: Text(AppStrings.deleteClass(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final err = await app.deleteTeacherClass(teacherClass.id);
    if (!mounted) return;
    if (err != null) {
      await TapTalkResultDialog.showError(
        context,
        title: AppStrings.somethingWentWrong(lang),
        message: err,
      );
      return;
    }
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.classDeletedTitle(lang),
      message: AppStrings.classDeleted(lang),
    );
  }

  Future<void> _editClass(({int id, String name, String code}) teacherClass) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final updated = await EditClassDialog.show(
      context,
      classId: teacherClass.id,
      initialName: app.localizedContent(teacherClass.name),
    );
    if (!mounted || updated != true) return;
    if (!mounted) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.classUpdatedTitle(lang),
      message: AppStrings.classUpdated(lang),
    );
  }

  void _openClass(({int id, String name, String code}) teacherClass) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TeacherClassDetailScreen(
              classId: teacherClass.id,
              className: teacherClass.name,
              classCode: teacherClass.code,
            ),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final classes = app.teacherClasses;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.teacherMyClasses,
      showBottomNav: false,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refresh(forceCloud: true),
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              96,
            ),
            children: [
              Text(
                AppStrings.myClasses(lang),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.textMain,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.teacherMyClassesSubtitle(lang),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: theme.textMain.withValues(alpha: 0.65),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (classes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9EEF2)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 48,
                        color: theme.bgAccent.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppStrings.noTeacherClasses(lang),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: theme.textMain.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final teacherClass in classes)
                  Padding(
                    key: ValueKey(
                      'tclass_${teacherClass.id}_${lang.name}_${app.languageRevision}',
                    ),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ClassColorCard(
                      classId: teacherClass.id,
                      title: teacherClass.name,
                      badge: teacherClass.code,
                      subtitle: AppStrings.studentsInClass(
                        app.teacherClassStudentCount(teacherClass.id),
                        lang,
                      ),
                      icon: Icons.menu_book_rounded,
                      onTap: () => _openClass(teacherClass),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') _editClass(teacherClass);
                          if (value == 'delete') _confirmDelete(teacherClass);
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  AppStrings.editClass(lang),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFC62828),
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  AppStrings.deleteClass(lang),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFC62828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                AppStrings.createClass(lang),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
