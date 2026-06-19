import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/live_refresh.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/class_lesson.dart';
import '../data/models/enrolled_class_model.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/localized_content_text.dart';
import 'learner_lesson_screen.dart';

class LearnerClassDetailScreen extends StatefulWidget {
  const LearnerClassDetailScreen({
    super.key,
    required this.enrolledClass,
  });

  final EnrolledClassModel enrolledClass;

  @override
  State<LearnerClassDetailScreen> createState() =>
      _LearnerClassDetailScreenState();
}

class _LearnerClassDetailScreenState extends State<LearnerClassDetailScreen> {
  List<ClassLesson> _lessons = [];
  int _lastContentRevision = 0;
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _app = context.read<AppState>();
      unawaited(_app!.startLiveClassContentSync(
        classId: widget.enrolledClass.classId,
        classCode: widget.enrolledClass.classCode,
      ));
      await _load();
    });
  }

  Future<void> _load({bool userRefresh = false}) async {
    final app = context.read<AppState>();
    try {
      final lessons = await app.getEnrolledClassLessons(
        widget.enrolledClass.classId,
        cloudSyncInBackground: !userRefresh,
      );
      if (!mounted) return;
      if (_sameLessons(_lessons, lessons)) return;
      setState(() => _lessons = lessons);
    } catch (e, st) {
      debugPrint('Learner class detail load failed: $e\n$st');
    }
  }

  Future<void> _openLesson(ClassLesson lesson) async {
    await Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => LearnerLessonScreen(
              lessonId: lesson.id,
              classId: widget.enrolledClass.classId,
              classCode: widget.enrolledClass.classCode,
              lessonTitle: lesson.title,
              className: widget.enrolledClass.className,
            ),
          ),
        );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final revision = app.classContentRevision(widget.enrolledClass.classId);
    _lastContentRevision = bindClassContentRevision(
      lastClassRevision: _lastContentRevision,
      classRevision: revision,
      reload: _load,
      isMounted: () => mounted,
    );
    final theme = app.theme;
    final lang = app.language;
    final enrolled = widget.enrolledClass;
    final displayClassName = app.localizedContent(enrolled.className);

    return LearnerScaffold(
      title: displayClassName,
      currentRoute: AppRoute.classes,
      showBackButton: true,
      showBottomNav: false,
      body: RefreshIndicator(
        onRefresh: () => _load(userRefresh: true),
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          ClassColorHeaderBanner(
            classId: enrolled.classId,
            title: enrolled.className,
            subtitle: enrolled.teacherName,
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
                AppStrings.noLessonsLearner(lang),
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
                ),
              ),
        ],
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
  });

  final ClassLesson lesson;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onTap;

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
