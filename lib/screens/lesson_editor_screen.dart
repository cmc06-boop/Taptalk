import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../data/models/lesson_phrase.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';
import '../widgets/phrase_composer_panel.dart';

class LessonEditorScreen extends StatefulWidget {
  const LessonEditorScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.className,
  });

  final int lessonId;
  final String lessonTitle;
  final String className;

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  List<LessonPhrase> _phrases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final phrases =
        await context.read<AppState>().getLessonPhrases(widget.lessonId);
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

  Future<void> _addPhrase(String text, String? imagePath) async {
    final app = context.read<AppState>();
    final err = await app.addLessonPhrase(
      widget.lessonId,
      text,
      imagePath: imagePath,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await _load();
  }

  Future<void> _deletePhrase(LessonPhrase phrase) async {
    final lang = context.read<AppState>().language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.deletePhrase(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.delete(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AppState>().deleteLessonPhrase(phrase.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final denseGrid = AppSpacing.phraseGridIsDense(context);

    return LearnerScaffold(
      title: widget.lessonTitle,
      currentRoute: AppRoute.teacherMyClasses,
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
                Text(
                  widget.lessonTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.className,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.lessonPhrasesSubtitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          PanelCard(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: PhraseComposerPanel(onAdd: _addPhrase),
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
                  AppStrings.noPhraseUsage(lang),
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
                  final label = app.localizedPhrase(phrase.text, phrase.categoryKey);
                  return PhraseCard(
                    phrase: phrase,
                    dense: denseGrid,
                    isFavorite: false,
                    showFavorite: false,
                    onTap: () => speakWithFeedback(context, label, record: false),
                    onSpeak: () => speakWithFeedback(context, label, record: false),
                    onFavorite: () {},
                    onDelete: () => _deletePhrase(lessonPhrase),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
