import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/navigation/route_transitions.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/class_color_card.dart';
import '../widgets/compact_popup_menu.dart';
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
  Future<void> _refresh({bool forceCloud = false}) async {
    await context.read<AppState>().refreshTeacherClasses(
          cloudSyncInBackground: !forceCloud,
        );
  }

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
          taptalkPageRoute<void>(
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      if (app.teacherClasses.isEmpty) {
        await _refresh();
      }
      await app.refreshPendingJoinRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final classes = app.teacherClasses;

    return LearnerScaffold(
      title: AppStrings.classes(lang),
      titleWidget: AppHeaderTitle(AppStrings.classes(lang)),
      currentRoute: AppRoute.teacherMyClasses,
      headerContentHeight: AppHeaderTitle.height,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      showBottomNav: false,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refresh(forceCloud: true),
            child: classes.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          96,
                        ),
                        children: [
                          SizedBox(
                            height: (constraints.maxHeight - 96)
                                .clamp(0.0, double.infinity),
                            child: Stack(
                              children: [
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                    ),
                                    child: Text(
                                      AppStrings.noTeacherClasses(lang),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: theme.textMain
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topRight,
                                  child: _ViewRequestsButton(
                                    count: app.pendingJoinRequestCount,
                                    onPressed: () => app.setRoute(
                                      AppRoute.teacherJoinRequests,
                                    ),
                                  ),
                                ),
                              ],
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
              96,
            ),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _ViewRequestsButton(
                  count: app.pendingJoinRequestCount,
                  onPressed: () => app.setRoute(AppRoute.teacherJoinRequests),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                      trailing: CompactPopupMenu(
                        iconColor: Colors.white.withValues(alpha: 0.92),
                        onSelected: (value) {
                          if (value == 'edit') _editClass(teacherClass);
                          if (value == 'delete') _confirmDelete(teacherClass);
                        },
                        actions: [
                          CompactMenuAction(
                            value: 'edit',
                            label: AppStrings.editClass(lang),
                            icon: Icons.edit_outlined,
                            color: theme.textMain,
                          ),
                          CompactMenuAction(
                            value: 'delete',
                            label: AppStrings.deleteClass(lang),
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFC62828),
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

class _ViewRequestsButton extends StatelessWidget {
  const _ViewRequestsButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: theme.bgAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            AppStrings.viewRequests(lang),
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: theme.bgLight, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
