import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../data/models/lesson_phrase.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import '../widgets/localized_content_text.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';

class LearnerLessonScreen extends StatefulWidget {
  const LearnerLessonScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.className,
  });

  final int lessonId;
  final String lessonTitle;
  final String className;

  @override
  State<LearnerLessonScreen> createState() => _LearnerLessonScreenState();
}

class _LearnerLessonScreenState extends State<LearnerLessonScreen> {
  List<LessonPhrase> _phrases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final phrases = await context
        .read<AppState>()
        .getEnrolledLessonPhrases(widget.lessonId);
    if (!mounted) return;
    setState(() {
      _phrases = phrases;
      _loading = false;
    });
  }

  PhraseModel _asPhraseModel(LessonPhrase phrase) {
    return PhraseModel(
      id: phrase.id,
      userId: 0,
      text: phrase.text,
      categoryKey: 'lesson',
      imagePath: phrase.imagePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final displayLessonTitle = app.localizedContent(widget.lessonTitle);

    return LearnerScaffold(
      title: displayLessonTitle,
      currentRoute: AppRoute.classes,
      showBackButton: true,
      showBottomNav: false,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          PanelCard(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedContentText(
                  widget.lessonTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                LocalizedContentText(
                  widget.className,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.welcomeSub(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.phrasesInLesson(lang),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.textMain,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_phrases.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  AppStrings.noPhrasesInLesson(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: theme.textMain.withValues(alpha: 0.65),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: AppSpacing.phraseGridDelegate(context),
                itemCount: _phrases.length,
                itemBuilder: (context, i) {
                  final lessonPhrase = _phrases[i];
                  final phrase = _asPhraseModel(lessonPhrase);
                  final displayText = app.localizedPhraseText(phrase);
                  return PhraseCard(
                    key: ValueKey('lesson_${phrase.id}_${lang.name}_${app.languageRevision}'),
                    phrase: phrase,
                    displayText: displayText,
                    dense: denseGrid,
                    isFavorite: app.isFavorite(phrase),
                    showDelete: false,
                    onTap: () => speakWithFeedback(
                      context,
                      displayText,
                      record: true,
                      categoryKey: phrase.categoryKey,
                      className: widget.className,
                      lessonTitle: widget.lessonTitle,
                    ),
                    onSpeak: () => speakWithFeedback(
                      context,
                      displayText,
                      record: true,
                      categoryKey: phrase.categoryKey,
                      className: widget.className,
                      lessonTitle: widget.lessonTitle,
                    ),
                    onFavorite: () => app.toggleFavorite(phrase),
                    onDelete: () {},
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
