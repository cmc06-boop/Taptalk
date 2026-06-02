import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/create_class_dialog.dart';
import '../widgets/taptalk_result_dialog.dart';
import '../widgets/learner_scaffold.dart';
import 'teacher_class_detail_screen.dart';

class TeacherMyClassesScreen extends StatefulWidget {
  const TeacherMyClassesScreen({super.key});

  @override
  State<TeacherMyClassesScreen> createState() => _TeacherMyClassesScreenState();
}

class _TeacherMyClassesScreenState extends State<TeacherMyClassesScreen> {
  final Map<int, int> _studentCounts = {};

  Future<void> _refreshCounts() async {
    final app = context.read<AppState>();
    final counts = <int, int>{};
    for (final c in app.teacherClasses) {
      counts[c.id] = await app.studentCountForClass(c.id);
    }
    if (!mounted) return;
    setState(() => _studentCounts.addAll(counts));
  }

  Future<void> _showCreateDialog() async {
    final lang = context.read<AppState>().language;
    final created = await CreateClassDialog.show(context);
    if (!mounted || created != true) return;
    await _refreshCounts();
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
        content: Text(AppStrings.deleteClassConfirm(lang, teacherClass.name)),
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
    setState(() => _studentCounts.remove(teacherClass.id));
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.classDeletedTitle(lang),
      message: AppStrings.classDeleted(lang),
    );
  }

  void _openClass(({int id, String name, String code}) teacherClass) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeacherClassDetailScreen(
          classId: teacherClass.id,
          className: teacherClass.name,
          classCode: teacherClass.code,
        ),
      ),
    ).then((_) => _refreshCounts());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCounts());
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
          ListView(
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
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ClassCard(
                      teacherClass: teacherClass,
                      theme: theme,
                      lang: lang,
                      studentCount: _studentCounts[teacherClass.id] ?? 0,
                      onOpen: () => _openClass(teacherClass),
                      onDelete: () => _confirmDelete(teacherClass),
                    ),
                  ),
            ],
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.teacherClass,
    required this.theme,
    required this.lang,
    required this.studentCount,
    required this.onOpen,
    required this.onDelete,
  });

  final ({int id, String name, String code}) teacherClass;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final int studentCount;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = theme.bgAccent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EEF2)),
            boxShadow: [
              BoxShadow(
                color: theme.textMain.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      teacherClass.name,
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
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.textMain.withValues(alpha: 0.55),
                ),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
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
              Icon(Icons.chevron_right_rounded, color: accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
