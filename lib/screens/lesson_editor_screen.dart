import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/live_refresh.dart';
import '../data/models/lesson_phrase.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import '../widgets/localized_content_text.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';
import '../widgets/phrase_composer_panel.dart';
import '../widgets/edit_phrase_dialog.dart';

class LessonEditorScreen extends StatefulWidget {
  const LessonEditorScreen({
    super.key,
    required this.lessonId,
    required this.classId,
    required this.classCode,
    required this.lessonTitle,
    required this.className,
  });

  final int lessonId;
  final int classId;
  final String classCode;
  final String lessonTitle;
  final String className;

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  List<LessonPhrase> _phrases = [];
  int _lastClassRevision = 0;
  AppState? _app;
  final _composerController = PhraseComposerPanelController();

  bool _samePhrases(List<LessonPhrase> a, List<LessonPhrase> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].text != b[i].text ||
          a[i].imagePath != b[i].imagePath) {
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
        classId: widget.classId,
        classCode: widget.classCode,
      ));
      await _load();
    });
  }

  Future<void> _load() async {
    final phrases =
        await context.read<AppState>().getLessonPhrases(widget.lessonId);
    if (!mounted) return;
    if (_samePhrases(_phrases, phrases)) return;
    setState(() => _phrases = phrases);
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
    setState(() => _phrases = _phrases.where((p) => p.id != phrase.id).toList());
    try {
      await context.read<AppState>().deleteLessonPhrase(phrase.id);
    } catch (_) {
      if (!mounted) return;
      await _load();
    }
  }

  Future<void> _editPhrase(LessonPhrase phrase) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final result = await EditPhraseDialog.show(
      context,
      initialText: app.localizedPhrase(phrase.text, 'lesson'),
      initialImagePath: phrase.imagePath,
      title: AppStrings.editPhrase(lang),
    );
    if (result == null || !mounted) return;
    final ok = await app.updateLessonPhrase(
      phrase.id,
      text: result.text,
      imagePath: result.imagePath,
      clearImage: result.clearImage,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _phrases = _phrases
            .map(
              (p) => p.id == phrase.id
                  ? LessonPhrase(
                      id: p.id,
                      lessonId: p.lessonId,
                      text: result.text,
                      imagePath: result.clearImage ? null : result.imagePath,
                    )
                  : p,
            )
            .toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.somethingWentWrong(lang))),
      );
    }
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
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final displayLessonTitle = app.localizedContent(widget.lessonTitle);

    return LearnerScaffold(
      title: displayLessonTitle,
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
            child: PhraseComposerPanel(
              composerController: _composerController,
              speakCategoryKey: 'lesson',
              recordOnPlay: false,
              onAdd: _addPhrase,
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
          if (_phrases.isEmpty)
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
                  final displayText = app.localizedPhraseText(phrase);
                  return PhraseCard(
                    key: ValueKey('lesson_${phrase.id}_${phrase.imagePath ?? ''}'),
                    phrase: phrase,
                    displayText: displayText,
                    dense: denseGrid,
                    isFavorite: false,
                    showFavorite: false,
                    onTap: () => _composerController.appendPhrase(
                      displayText,
                      speak: true,
                    ),
                    onSpeak: () => _composerController.appendPhrase(
                      displayText,
                      speak: true,
                    ),
                    onFavorite: () {},
                    onEdit: () => _editPhrase(lessonPhrase),
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
