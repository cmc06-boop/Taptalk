import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../providers/app_state.dart';
import '../services/stt_service.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/edit_phrase_dialog.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';
import '../widgets/phrase_section_header.dart';
import '../widgets/highlighting_text_controller.dart';
import '../widgets/tts_speed_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = HighlightingTextController();
  final _categoryScroll = ScrollController();
  final _undoStack = <String>[];
  final SttService _stt = SttService();
  bool _listening = false;
  String _micSessionPrefix = '';
  String? _attachedImagePath;

  @override
  void initState() {
    super.initState();
    _undoStack.add('');
    _textController.addListener(() {
      if (_undoStack.isEmpty || _undoStack.last != _textController.text) {
        _undoStack.add(_textController.text);
      }
    });
  }

  @override
  void dispose() {
    _stt.cancel();
    _textController.dispose();
    _categoryScroll.dispose();
    super.dispose();
  }

  void _syncMicListening() {
    if (!mounted) return;
    final active = _stt.isListening;
    if (_listening != active) {
      setState(() => _listening = active);
    }
  }

  Future<void> _toggleMic() async {
    final app = context.read<AppState>();
    if (_listening || _stt.isListening) {
      await _stt.stop();
      _syncMicListening();
      return;
    }

    final ready = await _stt.initialize(
      onStatus: (_) => _syncMicListening(),
      onError: (error) {
        _syncMicListening();
        if (!mounted) return;
        if (error.permanent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.speechNotAvailable(app.language))),
          );
        }
      },
    );

    if (!ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.speechNotAvailable(app.language))),
      );
      return;
    }

    _micSessionPrefix = _textController.text;
    if (_micSessionPrefix.isNotEmpty && !_micSessionPrefix.endsWith(' ')) {
      _micSessionPrefix = '$_micSessionPrefix ';
    }

    setState(() => _listening = true);

    final locale = await _stt.resolveLocale(app.language);
    final started = await _stt.startListening(
      localeId: locale,
      onResult: (words, isFinal) {
        if (words.trim().isEmpty) return;
        if (!mounted) return;
        setState(() {
          _textController.text = '$_micSessionPrefix${words.trim()}';
        });
      },
    );
    _syncMicListening();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.speechNotAvailable(app.language))),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 900);
    if (file != null) {
      setState(() => _attachedImagePath = file.path);
    }
  }

  void _appendPhrase(String text, {bool speak = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _textController.text.trim();
    _textController.text = current.isEmpty ? trimmed : '$current $trimmed';
    if (speak) {
      speakWithFeedback(context, trimmed, record: true);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    await AddCategoryDialog.show(context);
  }

  Future<void> _refresh() async {
    await context.read<AppState>().refreshLearnerCollections();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final userName = app.user?.fullName ?? AppStrings.defaultLearnerName(lang);
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final highlightController = _textController;
    if (highlightController is HighlightingTextController) {
      final (start, end) =
          app.composerHighlightRange(_textController.text);
      highlightController.updateHighlight(
        start: start,
        end: end,
        accent: theme.bgAccent,
      );
    }

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.home,
      onMicTap: _toggleMic,
      micActive: _listening,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.bgAccent,
        child: ListView(
        key: ValueKey('home_${lang.name}_${app.languageRevision}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          PanelCard(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.welcomeUser(userName, lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: theme.textMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.welcomeSub(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.categories(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddCategoryDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    AppStrings.addCategoryShort(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              controller: _categoryScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: app.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final cat = app.categories[i];
                final active = cat.key == app.selectedCategoryKey;
                return FilterChip(
                  key: ValueKey('cat_${cat.key}_${lang.name}_${app.languageRevision}'),
                  selected: active,
                  showCheckmark: false,
                  label: Text(app.localizedCategoryName(cat)),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? Colors.white : theme.textMain,
                  ),
                  selectedColor: theme.bgAccent,
                  backgroundColor: Colors.white.withValues(alpha: 0.65),
                  side: BorderSide(color: theme.bgMid, width: 1.5),
                  onSelected: (_) => app.selectCategory(cat.key),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.enterText(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.textMain,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.undo_rounded, size: 22),
                          onPressed: _undoStack.length <= 1
                              ? null
                              : () {
                                  _undoStack.removeLast();
                                  _textController.text = _undoStack.last;
                                },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 22),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _textController.text),
                            );
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () async {
                            await app.stopSpeech();
                            _textController.clear();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (_attachedImagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: Image.file(
                            File(_attachedImagePath!),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            AppStrings.imageAttached(lang),
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _attachedImagePath = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFE2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: theme.textMain,
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          hintText: AppStrings.enterText(lang),
                          filled: true,
                          fillColor: const Color(0xFFF4F4F4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.end,
                          runAlignment: WrapAlignment.end,
                          children: [
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.bgAccent,
                              backgroundColor: Colors.white.withValues(alpha: 0.92),
                              side: BorderSide(
                                color: theme.bgAccent.withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                            icon: Icon(
                              Icons.image_outlined,
                              size: 16,
                              color: theme.bgAccent,
                            ),
                            label: Text(
                              AppStrings.attachImage(lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.bgAccent,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await app.addPhrase(
                                _textController.text,
                                imagePath: _attachedImagePath,
                              );
                              _textController.clear();
                              setState(() => _attachedImagePath = null);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.bgAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              AppStrings.add(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: () => speakWithFeedback(
                        context,
                        _textController.text,
                        record: true,
                      ),
                      style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(AppStrings.play(lang)),
                    ),
                    FilledButton.icon(
                      onPressed: () => app.pauseSpeech(),
                      style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
                      icon: const Icon(Icons.pause_rounded),
                      label: Text(AppStrings.pause(lang)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TtsSpeedSelector(
                  showScaleLabels: true,
                  sectionLabel: AppStrings.speechSpeed(lang),
                ),
              ],
            ),
          ),
          PhraseSectionHeader(
            category: app.selectedCategory,
            categoryLabel: app.selectedCategory != null
                ? app.localizedCategoryName(app.selectedCategory!)
                : AppStrings.customCategory(lang),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: GridView.builder(
              key: ValueKey('phrases_${lang.name}_${app.languageRevision}_${app.selectedCategoryKey}'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: AppSpacing.phraseGridDelegate(context),
              itemCount: app.phrasesForCategory.length,
              itemBuilder: (context, i) {
                final phrase = app.phrasesForCategory[i];
                return PhraseCard(
                  key: ValueKey('phrase_${phrase.id}_${lang.name}_${app.languageRevision}'),
                  phrase: phrase,
                  dense: denseGrid,
                  isFavorite: app.isFavorite(phrase),
                  onTap: () => _appendPhrase(app.localizedPhraseText(phrase)),
                  onSpeak: () =>
                      _appendPhrase(app.localizedPhraseText(phrase), speak: true),
                  onFavorite: () => app.toggleFavorite(phrase),
                  onEdit: () async {
                    if (phrase.isBuiltin) return;
                    final result = await EditPhraseDialog.show(
                      context,
                      initialText: app.localizedPhraseText(phrase),
                      initialImagePath: phrase.imagePath,
                      title: AppStrings.editPhrase(lang),
                    );
                    if (result == null || !mounted) return;
                    await app.updatePhrase(
                      phrase,
                      text: result.text,
                      imagePath: result.imagePath,
                      clearImage: result.clearImage,
                    );
                  },
                  onDelete: () async {
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
                    if (confirm == true) await app.deletePhrase(phrase);
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}
