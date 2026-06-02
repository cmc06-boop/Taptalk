import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/class_lesson.dart';
import '../data/models/enrolled_class_model.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lessons = await context
        .read<AppState>()
        .getEnrolledClassLessons(widget.enrolledClass.classId);
    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _loading = false;
    });
  }

  void _openLesson(ClassLesson lesson) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => LearnerLessonScreen(
              lessonId: lesson.id,
              lessonTitle: lesson.title,
              className: widget.enrolledClass.className,
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
    final enrolled = widget.enrolledClass;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.classes,
      showBackButton: true,
      showBottomNav: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          PanelCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enrolled.className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  enrolled.teacherName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.textMain.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                  lesson: lesson,
                  theme: theme,
                  lang: lang,
                  onTap: () => _openLesson(lesson),
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
