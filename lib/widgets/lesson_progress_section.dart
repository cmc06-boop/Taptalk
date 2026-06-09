import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/child_lesson_progress.dart';
import '../data/models/class_lesson.dart';
import '../data/models/enrolled_class_model.dart';
import '../providers/app_state.dart';
import 'inline_dropdown_field.dart';
import 'lesson_progress_ring.dart';

enum _OpenPicker { none, classPicker, lessonPicker }

class LessonProgressSection extends StatefulWidget {
  const LessonProgressSection({
    super.key,
    required this.learnerUserId,
    required this.period,
    required this.month,
    required this.reloadNonce,
    this.syncCloudOnReload = false,
    required this.theme,
    required this.lang,
    required this.labelForContent,
  });

  final int learnerUserId;
  final ChildUsagePeriod period;
  final DateTime? month;
  final int reloadNonce;
  final bool syncCloudOnReload;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String text) labelForContent;

  @override
  State<LessonProgressSection> createState() => _LessonProgressSectionState();
}

class _LessonProgressSectionState extends State<LessonProgressSection> {
  List<EnrolledClassModel> _classes = [];
  List<ClassLesson> _lessons = [];
  EnrolledClassModel? _selectedClass;
  ClassLesson? _selectedLesson;
  ChildLessonProgressEntry? _progress;
  _OpenPicker _openPicker = _OpenPicker.none;

  @override
  void initState() {
    super.initState();
    _loadClasses(syncCloud: false);
  }

  @override
  void didUpdateWidget(covariant LessonProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadNonce != widget.reloadNonce &&
        widget.syncCloudOnReload) {
      unawaited(_loadClasses(syncCloud: true));
    }
    if (oldWidget.period != widget.period ||
        oldWidget.month != widget.month ||
        oldWidget.reloadNonce != widget.reloadNonce) {
      if (_selectedClass != null && _selectedLesson != null) {
        _loadProgress(_selectedClass!, _selectedLesson!, silent: true);
      }
    }
  }

  Future<void> _loadClasses({bool syncCloud = false}) async {
    try {
      final app = context.read<AppState>();
      final classes = await app.getEnrolledClassesForMonitoring(
        widget.learnerUserId,
        syncCloud: syncCloud,
      );
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _selectedClass = classes.isNotEmpty ? classes.first : null;
        _selectedLesson = null;
        _lessons = [];
        _progress = null;
        _openPicker = _OpenPicker.none;
      });
      if (_selectedClass != null) {
        await _loadLessons(
          _selectedClass!,
          silent: true,
          syncCloud: syncCloud,
        );
      }
    } catch (e, st) {
      debugPrint('Lesson progress classes load failed: $e\n$st');
    }
  }

  Future<void> _loadLessons(
    EnrolledClassModel enrolled, {
    bool silent = false,
    bool syncCloud = false,
  }) async {
    if (!silent && mounted) {
      setState(() {
        _lessons = [];
        _selectedLesson = null;
        _progress = null;
        _openPicker = _OpenPicker.none;
      });
    }
    try {
      final app = context.read<AppState>();
      final lessons = await app.getClassLessonsForMonitoring(
        classId: enrolled.classId,
        classCode: enrolled.classCode,
        syncCloud: syncCloud,
      );
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _selectedLesson = lessons.isNotEmpty ? lessons.first : null;
      });
      if (_selectedLesson != null && _selectedClass != null) {
        await _loadProgress(_selectedClass!, _selectedLesson!, silent: true);
      }
    } catch (e, st) {
      debugPrint('Lesson progress lessons load failed: $e\n$st');
    }
  }

  Future<void> _loadProgress(
    EnrolledClassModel enrolled,
    ClassLesson lesson, {
    bool silent = false,
  }) async {
    try {
      final app = context.read<AppState>();
      final progress = await app.getLessonProgressForMonitoring(
        learnerUserId: widget.learnerUserId,
        className: enrolled.className,
        lessonTitle: lesson.title,
        period: widget.period,
        month: widget.month,
      );
      if (!mounted) return;
      setState(() => _progress = progress);
    } catch (e, st) {
      debugPrint('Lesson progress load failed: $e\n$st');
    }
  }

  void _togglePicker(_OpenPicker picker) {
    setState(() {
      _openPicker = _openPicker == picker ? _OpenPicker.none : picker;
    });
  }

  Future<void> _onClassSelected(EnrolledClassModel picked) async {
    if (_selectedClass == picked) {
      setState(() => _openPicker = _OpenPicker.none);
      return;
    }
    setState(() {
      _selectedClass = picked;
      _openPicker = _OpenPicker.none;
    });
    await _loadLessons(picked);
  }

  Future<void> _onLessonSelected(ClassLesson picked) async {
    if (_selectedLesson == picked || _selectedClass == null) {
      setState(() => _openPicker = _OpenPicker.none);
      return;
    }
    setState(() {
      _selectedLesson = picked;
      _openPicker = _OpenPicker.none;
    });
    await _loadProgress(_selectedClass!, picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;

    if (_classes.isEmpty) {
      return Text(
        AppStrings.noClassesEnrolled(lang),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: theme.textMain.withValues(alpha: 0.7),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.lessonProgressSubtitle(lang),
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: theme.textMain.withValues(alpha: 0.62),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        InlineDropdownField<EnrolledClassModel>(
          label: AppStrings.selectClass(lang),
          value: _selectedClass == null
              ? null
              : widget.labelForContent(_selectedClass!.className),
          options: _classes,
          optionLabel: (c) => widget.labelForContent(c.className),
          selected: _selectedClass,
          isOpen: _openPicker == _OpenPicker.classPicker,
          theme: theme,
          onToggle: () => _togglePicker(_OpenPicker.classPicker),
          onSelected: _onClassSelected,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_lessons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              AppStrings.noLessonsInClass(lang),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: theme.textMain.withValues(alpha: 0.7),
              ),
            ),
          )
        else ...[
          InlineDropdownField<ClassLesson>(
            label: AppStrings.selectLesson(lang),
            value: _selectedLesson == null
                ? null
                : widget.labelForContent(_selectedLesson!.title),
            options: _lessons,
            optionLabel: (l) => widget.labelForContent(l.title),
            selected: _selectedLesson,
            isOpen: _openPicker == _OpenPicker.lessonPicker,
            theme: theme,
            onToggle: () => _togglePicker(_OpenPicker.lessonPicker),
            onSelected: _onLessonSelected,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_progress != null &&
              _selectedLesson != null &&
              _selectedClass != null)
            _LessonProgressCard(
              className: _selectedClass!.className,
              entry: _progress!,
              lesson: _selectedLesson!,
              theme: theme,
              lang: lang,
              labelForContent: widget.labelForContent,
            ),
        ],
      ],
    );
  }
}

class _LessonProgressCard extends StatelessWidget {
  const _LessonProgressCard({
    required this.className,
    required this.entry,
    required this.lesson,
    required this.theme,
    required this.lang,
    required this.labelForContent,
  });

  final String className;
  final ChildLessonProgressEntry entry;
  final ClassLesson lesson;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String text) labelForContent;

  @override
  Widget build(BuildContext context) {
    final total = entry.totalPhrases ?? lesson.phraseCount;
    final tapped = entry.practicedPhrases;
    final percent = total > 0 ? entry.progressPercent : 0;
    final timeFmt = DateFormat('d MMM - h:mm a');
    final lastUsed = entry.lastAccessed;
    final formattedLastUsed =
        lastUsed != null ? timeFmt.format(lastUsed) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.bgMid.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelForContent(className),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textMain.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labelForContent(entry.lessonTitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  formattedLastUsed != null
                      ? '${AppStrings.lastUsedAt(lang)}: $formattedLastUsed'
                      : AppStrings.lessonNotUsedYet(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: theme.textMain.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          LessonProgressRing(
            percent: percent,
            tapped: tapped,
            total: total,
            theme: theme,
            lang: lang,
          ),
        ],
      ),
    );
  }
}
