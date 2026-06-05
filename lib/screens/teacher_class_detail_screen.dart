import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/class_lesson.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
import '../widgets/create_lesson_dialog.dart';
import '../widgets/taptalk_result_dialog.dart';
import '../widgets/learner_scaffold.dart';
import 'lesson_editor_screen.dart';

class TeacherClassDetailScreen extends StatefulWidget {
  const TeacherClassDetailScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.classCode,
  });

  final int classId;
  final String className;
  final String classCode;

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen> {
  List<ClassLesson> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lessons =
        await context.read<AppState>().getClassLessons(widget.classId);
    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _loading = false;
    });
  }

  Future<void> _createLesson() async {
    final lang = context.read<AppState>().language;
    final created = await CreateLessonDialog.show(
      context,
      classId: widget.classId,
    );
    if (!mounted || created != true) return;
    await _load();
    if (!mounted) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.lessonCreatedTitle(lang),
      message: AppStrings.lessonCreated(lang),
    );
  }

  Future<void> _confirmDeleteLesson(ClassLesson lesson) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppStrings.deleteLesson(lang),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(AppStrings.deleteLessonConfirm(lang, lesson.title)),
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
            child: Text(AppStrings.deleteLesson(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await app.deleteClassLesson(lesson.id);
    await _load();
  }

  void _openLesson(ClassLesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonEditorScreen(
          lessonId: lesson.id,
          lessonTitle: lesson.title,
          className: widget.className,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _copyCode() async {
    final lang = context.read<AppState>().language;
    await Clipboard.setData(ClipboardData(text: widget.classCode));
    if (!mounted) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.copiedTitle(lang),
      message: AppStrings.copied(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return LearnerScaffold(
      title: widget.className,
      currentRoute: AppRoute.teacherMyClasses,
      showBackButton: true,
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
              _ClassHeaderBanner(
                classId: widget.classId,
                className: widget.className,
                classCode: widget.classCode,
                onCopyCode: _copyCode,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.lessons(lang),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.textMain,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_lessons.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9EEF2)),
                  ),
                  child: Text(
                    AppStrings.noLessons(lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: theme.textMain.withValues(alpha: 0.7),
                    ),
                  ),
                )
              else
                for (final lesson in _lessons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _LessonCard(
                      lesson: lesson,
                      theme: theme,
                      lang: lang,
                      onTap: () => _openLesson(lesson),
                      onDelete: () => _confirmDeleteLesson(lesson),
                    ),
                  ),
            ],
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: FloatingActionButton.extended(
              onPressed: _createLesson,
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                AppStrings.createLesson(lang),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassHeaderBanner extends StatelessWidget {
  const _ClassHeaderBanner({
    required this.classId,
    required this.className,
    required this.classCode,
    required this.onCopyCode,
  });

  final int classId;
  final String className;
  final String classCode;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    final colors = ClassColorPalette.forClass(classId);

    return Container(
      decoration: BoxDecoration(
        gradient: colors.gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          Positioned.fill(
            child: ClassBubbleDecor(seed: classId),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.iconBg,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ClassCodeChip(
                        code: classCode,
                        colors: colors,
                        onCopy: onCopyCode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCodeChip extends StatelessWidget {
  const _ClassCodeChip({
    required this.code,
    required this.colors,
    required this.onCopy,
  });

  final String code;
  final ClassColorScheme colors;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.badgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.theme,
    required this.lang,
    required this.onTap,
    required this.onDelete,
  });

  final ClassLesson lesson;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EEF2)),
            boxShadow: [
              BoxShadow(
                color: theme.textMain.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.bgAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories_outlined, color: theme.bgAccent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.phrasesCount(lesson.phraseCount, lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textMain.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.textMain.withValues(alpha: 0.5),
                ),
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      AppStrings.deleteLesson(lang),
                      style: const TextStyle(color: Color(0xFFC62828)),
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.bgAccent,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
