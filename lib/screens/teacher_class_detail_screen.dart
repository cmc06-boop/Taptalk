import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/navigation/route_transitions.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/live_refresh.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/class_lesson.dart';
import '../providers/app_state.dart';
import '../widgets/localized_content_text.dart';
import '../widgets/class_color_card.dart';
import '../widgets/compact_popup_menu.dart';
import '../widgets/create_lesson_dialog.dart';
import '../widgets/code_qr_sheet.dart';
import '../widgets/taptalk_result_dialog.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/student_count_badge.dart';
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
  int _studentCount = 0;
  late String _className;
  int _lastClassRevision = 0;
  AppState? _app;

  bool _sameLessons(List<ClassLesson> a, List<ClassLesson> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].phraseCount != b[i].phraseCount) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _className = widget.className;
    _studentCount =
        context.read<AppState>().teacherClassStudentCount(widget.classId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _app = context.read<AppState>();
      unawaited(_app!.startLiveClassContentSync(
        classId: widget.classId,
        classCode: widget.classCode,
      ));
      await _load();
    });
  }

  Future<void> _load({bool userRefresh = false}) async {
    final app = context.read<AppState>();
    try {
      final cached = await Future.wait([
        app.getTeacherClassLessonsForDisplay(
          widget.classId,
          cloudSyncInBackground: !userRefresh,
        ),
        app.getTeacherClassStudentsForClass(
          widget.classId,
          cloudSyncInBackground: true,
        ),
      ]);
      if (!mounted) return;
      final nextLessons = cached[0] as List<ClassLesson>;
      final nextCount = (cached[1] as List).length;
      if (_sameLessons(_lessons, nextLessons) && _studentCount == nextCount) {
        return;
      }
      setState(() {
        _lessons = nextLessons;
        _studentCount = nextCount;
      });
    } catch (e, st) {
      debugPrint('Teacher class detail load failed: $e\n$st');
    }
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

  Future<void> _editLesson(ClassLesson lesson) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final updated = await CreateLessonDialog.show(
      context,
      classId: widget.classId,
      lessonId: lesson.id,
      initialTitle: app.localizedContent(lesson.title),
    );
    if (!mounted || updated != true) return;
    await _load();
    if (!mounted) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.lessonUpdatedTitle(lang),
      message: AppStrings.lessonUpdated(lang),
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
        content: Text(
          AppStrings.deleteLessonConfirm(
            lang,
            app.localizedContent(lesson.title),
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
      taptalkPageRoute<void>(
        builder: (_) => LessonEditorScreen(
          lessonId: lesson.id,
          classId: widget.classId,
          classCode: widget.classCode,
          lessonTitle: lesson.title,
          className: _className,
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

  void _showClassQr() {
    final lang = context.read<AppState>().language;
    CodeQrSheet.show(
      context,
      title: AppStrings.showQrCode(lang),
      code: widget.classCode,
      subtitle: AppStrings.classCodeHint(lang),
      shareMessage: AppStrings.shareClassCodeMessage(lang, widget.classCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _lastClassRevision = bindClassContentRevision(
      lastClassRevision: _lastClassRevision,
      classRevision: app.classContentRevision(widget.classId),
      reload: _load,
      isMounted: () => mounted,
    );
    final theme = app.theme;
    final lang = app.language;
    final displayClassName = app.localizedContent(_className);

    return LearnerScaffold(
      title: displayClassName,
      titleBadge: StudentCountBadge(
        count: _studentCount,
        accent: theme.bgAccent,
      ),
      currentRoute: AppRoute.teacherMyClasses,
      showBottomNav: false,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(userRefresh: true),
            color: theme.bgAccent,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              96,
            ),
            children: [
              _ClassHeaderBanner(
                classId: widget.classId,
                className: _className,
                classCode: widget.classCode,
                onCopyCode: _copyCode,
                onShowQr: _showClassQr,
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
              if (_lessons.isEmpty)
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
                      key: ValueKey(
                        'lesson_${lesson.id}_${lang.name}_${app.languageRevision}',
                      ),
                      lesson: lesson,
                      theme: theme,
                      lang: lang,
                      onTap: () => _openLesson(lesson),
                      onEdit: () => _editLesson(lesson),
                      onDelete: () => _confirmDeleteLesson(lesson),
                    ),
                  ),
            ],
            ),
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
    required this.onShowQr,
  });

  final int classId;
  final String className;
  final String classCode;
  final VoidCallback onCopyCode;
  final VoidCallback onShowQr;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LocalizedContentText(
                        className,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _BannerQrButton(colors: colors, onTap: onShowQr),
                  ],
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onCopyCode,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.badgeBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      classCode,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
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

/// Translucent QR chip that reads over the class banner's gradient.
class _BannerQrButton extends StatelessWidget {
  const _BannerQrButton({required this.colors, required this.onTap});

  final ClassColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.qr_code_2_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    super.key,
    required this.lesson,
    required this.theme,
    required this.lang,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassLesson lesson;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onTap;
  final VoidCallback onEdit;
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
                    LocalizedContentText(
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
              CompactPopupMenu(
                iconColor: theme.textMain.withValues(alpha: 0.5),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                actions: [
                  CompactMenuAction(
                    value: 'edit',
                    label: AppStrings.editLesson(lang),
                    icon: Icons.edit_outlined,
                    color: theme.textMain,
                  ),
                  CompactMenuAction(
                    value: 'delete',
                    label: AppStrings.deleteLesson(lang),
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFC62828),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
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
