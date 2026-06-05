import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/child_lesson_progress.dart';

class LessonProgressSection extends StatelessWidget {
  const LessonProgressSection({
    super.key,
    required this.entries,
    required this.theme,
    required this.lang,
    required this.labelForContent,
  });

  final List<ChildLessonProgressEntry> entries;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String text) labelForContent;

  Map<String, List<ChildLessonProgressEntry>> _groupByClass() {
    final grouped = <String, List<ChildLessonProgressEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.className, () => []).add(entry);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        AppStrings.noLessonProgress(lang),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: theme.textMain.withValues(alpha: 0.7),
        ),
      );
    }

    final grouped = _groupByClass();
    final classNames = grouped.keys.toList()..sort();
    final timeFmt = DateFormat('d MMM - h:mm a');

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
        for (final className in classNames) ...[
          Text(
            labelForContent(className),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.textMain,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in grouped[className]!)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LessonProgressCard(
                entry: entry,
                theme: theme,
                lang: lang,
                labelForContent: labelForContent,
                formattedLastUsed: timeFmt.format(entry.lastAccessed),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _LessonProgressCard extends StatelessWidget {
  const _LessonProgressCard({
    required this.entry,
    required this.theme,
    required this.lang,
    required this.labelForContent,
    required this.formattedLastUsed,
  });

  final ChildLessonProgressEntry entry;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String text) labelForContent;
  final String formattedLastUsed;

  @override
  Widget build(BuildContext context) {
    final progress = entry.progressFraction;
    final totalPhrases = entry.totalPhrases;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.bgMid.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.bgAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  color: theme.bgAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  labelForContent(entry.lessonTitle),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textMain,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.textMain.withValues(alpha: 0.08),
                color: theme.bgAccent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.lessonPhrasesPracticed(
                entry.practicedPhrases,
                totalPhrases!,
                lang,
              ),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.bgAccent,
              ),
            ),
          ] else if (entry.practicedPhrases > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.phrasesCount(entry.practicedPhrases, lang),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.bgAccent,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${AppStrings.lastUsedAt(lang)}: $formattedLastUsed',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: theme.textMain.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}
