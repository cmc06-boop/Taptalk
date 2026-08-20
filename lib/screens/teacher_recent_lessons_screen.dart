import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/navigation/route_transitions.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/teacher_recent_lesson.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
import '../widgets/learner_scaffold.dart';
import 'lesson_editor_screen.dart';

class TeacherRecentLessonsScreen extends StatefulWidget {
  const TeacherRecentLessonsScreen({super.key});

  @override
  State<TeacherRecentLessonsScreen> createState() =>
      _TeacherRecentLessonsScreenState();
}

class _TeacherRecentLessonsScreenState
    extends State<TeacherRecentLessonsScreen> {
  List<TeacherRecentLesson> _lessons = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool userRefresh = false}) async {
    if (userRefresh || _lessons.isEmpty) setState(() => _loading = true);
    final app = context.read<AppState>();
    if (userRefresh || app.teacherClasses.isEmpty) {
      await app.refreshTeacherClasses(cloudSyncInBackground: true);
    }
    final lessons = await app.getTeacherLessonHistory();
    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _loading = false;
    });
  }

  static String _sectionLabel(DateTime date, AppLanguage lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return AppStrings.todayLabel(lang);
    if (day == today.subtract(const Duration(days: 1))) {
      return AppStrings.yesterdayLabel(lang);
    }
    final locale = lang == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    return DateFormat.yMMMMd(locale).format(date);
  }

  static Map<String, List<TeacherRecentLesson>> _groupBySection(
    List<TeacherRecentLesson> items,
    AppLanguage lang,
  ) {
    final grouped = <String, List<TeacherRecentLesson>>{};
    for (final item in items) {
      final key = _sectionLabel(item.createdAt, lang);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  void _openLesson(TeacherRecentLesson lesson) {
    final app = context.read<AppState>();
    final teacherClass = app.teacherClasses.where((c) => c.id == lesson.classId);
    if (teacherClass.isEmpty) return;
    final classInfo = teacherClass.first;

    Navigator.of(context)
        .push(
          taptalkPageRoute<void>(
            builder: (_) => LessonEditorScreen(
              lessonId: lesson.id,
              classId: lesson.classId,
              classCode: classInfo.code,
              lessonTitle: lesson.title,
              className: lesson.className,
            ),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final grouped = _groupBySection(_lessons, lang);
    final sectionKeys = grouped.keys.toList();

    return LearnerScaffold(
      title: AppStrings.recentLessons(lang),
      currentRoute: AppRoute.teacherRecentLessons,
      showBottomNav: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.recentLessonsSubtitle(lang),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.textMain.withValues(alpha: 0.65),
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: theme.bgAccent),
                  )
                : _lessons.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            AppStrings.noRecentLessons(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: theme.textMain.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(userRefresh: true),
                        color: theme.bgAccent,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                          itemCount: sectionKeys.length,
                          itemBuilder: (context, sectionIndex) {
                            final section = sectionKeys[sectionIndex];
                            final sectionItems = grouped[section]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.sm,
                                  ),
                                  child: Text(
                                    section,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textMain.withValues(
                                        alpha: 0.55,
                                      ),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                for (final lesson in sectionItems)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      0,
                                      AppSpacing.lg,
                                      AppSpacing.sm,
                                    ),
                                    child: ClassColorCard(
                                      classId: lesson.classId,
                                      title: lesson.title,
                                      subtitle:
                                          '${app.localizedContent(lesson.className)}\n${AppStrings.phrasesCount(lesson.phraseCount, lang)}',
                                      icon: Icons.auto_stories_rounded,
                                      onTap: () => _openLesson(lesson),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
