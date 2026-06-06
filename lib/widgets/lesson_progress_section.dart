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
import 'lesson_progress_ring.dart';

enum _OpenPicker { none, classPicker, lessonPicker }

class LessonProgressSection extends StatefulWidget {
  const LessonProgressSection({
    super.key,
    required this.learnerUserId,
    required this.period,
    required this.month,
    required this.reloadNonce,
    required this.theme,
    required this.lang,
    required this.labelForContent,
  });

  final int learnerUserId;
  final ChildUsagePeriod period;
  final DateTime? month;
  final int reloadNonce;
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
  bool _loadingClasses = true;
  bool _loadingLessons = false;
  bool _loadingProgress = false;
  _OpenPicker _openPicker = _OpenPicker.none;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void didUpdateWidget(covariant LessonProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period ||
        oldWidget.month != widget.month ||
        oldWidget.reloadNonce != widget.reloadNonce) {
      if (_selectedClass != null && _selectedLesson != null) {
        _loadProgress(_selectedClass!, _selectedLesson!, silent: true);
      }
    }
  }

  Future<void> _loadClasses() async {
    if (mounted) setState(() => _loadingClasses = true);
    try {
      final app = context.read<AppState>();
      final classes = await app.getEnrolledClassesForMonitoring(
        widget.learnerUserId,
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
        await _loadLessons(_selectedClass!, silent: true);
      }
    } catch (e, st) {
      debugPrint('Lesson progress classes load failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadLessons(
    EnrolledClassModel enrolled, {
    bool silent = false,
  }) async {
    if (!silent && mounted) {
      setState(() {
        _loadingLessons = true;
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
      );
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _selectedLesson = lessons.isNotEmpty ? lessons.first : null;
      });
      if (_selectedLesson != null && _selectedClass != null) {
        await _loadProgress(_selectedClass!, _selectedLesson!, silent: silent);
      }
    } catch (e, st) {
      debugPrint('Lesson progress lessons load failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingLessons = false);
    }
  }

  Future<void> _loadProgress(
    EnrolledClassModel enrolled,
    ClassLesson lesson, {
    bool silent = false,
  }) async {
    if (!silent && mounted) setState(() => _loadingProgress = true);
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
    } finally {
      if (mounted) setState(() => _loadingProgress = false);
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

    if (_loadingClasses) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
        _InlineDropdownField<EnrolledClassModel>(
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
        if (_loadingLessons)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_lessons.isEmpty)
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
          _InlineDropdownField<ClassLesson>(
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
          if (_loadingProgress)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_progress != null &&
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

class _InlineDropdownField<T> extends StatelessWidget {
  const _InlineDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.isOpen,
    required this.theme,
    required this.onToggle,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final List<T> options;
  final String Function(T) optionLabel;
  final T? selected;
  final bool isOpen;
  final TapTalkThemeToken theme;
  final VoidCallback onToggle;
  final ValueChanged<T> onSelected;

  static const _borderColor = Color(0xFFE9EEF2);

  @override
  Widget build(BuildContext context) {
    final fieldRadius = BorderRadius.circular(10);
    final openFieldRadius = const BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    );
    final menuRadius = const BorderRadius.only(
      bottomLeft: Radius.circular(10),
      bottomRight: Radius.circular(10),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.bgMid.withValues(alpha: 0.35),
          borderRadius: isOpen ? openFieldRadius : fieldRadius,
          child: InkWell(
            onTap: options.isEmpty ? null : onToggle,
            borderRadius: isOpen ? openFieldRadius : fieldRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                borderRadius: isOpen ? openFieldRadius : fieldRadius,
                border: Border.all(
                  color: isOpen ? theme.bgAccent.withValues(alpha: 0.35) : _borderColor,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.textMain.withValues(alpha: 0.52),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          value ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textMain,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: theme.textMain.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: isOpen
              ? Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: theme.textMain.withValues(alpha: 0.12),
                  borderRadius: menuRadius,
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: theme.bgAccent.withValues(alpha: 0.35),
                        ),
                        right: BorderSide(
                          color: theme.bgAccent.withValues(alpha: 0.35),
                        ),
                        bottom: BorderSide(
                          color: theme.bgAccent.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: _borderColor),
                      itemBuilder: (_, index) {
                        final option = options[index];
                        final isSelected = option == selected;
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm + 2,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    optionLabel(option),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.bgAccent
                                          : theme.textMain,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: theme.bgAccent,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
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
