import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/profanity_filter.dart';
import '../core/utils/speak_feedback.dart';
import '../providers/app_state.dart';
import '../services/stt_service.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/edit_phrase_dialog.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';
import '../widgets/highlighting_text_controller.dart';
import '../widgets/tts_speed_selector.dart';
import '../widgets/view_phrase_dialog.dart';
import '../widgets/composer_attachment_preview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = HighlightingTextController();
  final ScrollController _composerScroll = ScrollController();
  final _undoStack = <String>[];
  final SttService _stt = SttService();
  bool _listening = false;
  int _micRequestId = 0;
  String _micSessionPrefix = '';
  String _micSessionWords = '';
  String? _attachedImagePath;

  @override
  void initState() {
    super.initState();
    _undoStack.add('');
    _textController.addListener(() {
      if (_undoStack.isEmpty || _undoStack.last != _textController.text) {
        _undoStack.add(_textController.text);
      }
      _keepComposerEndVisible();
    });
  }

  @override
  void dispose() {
    _stt.cancel();
    _textController.dispose();
    _composerScroll.dispose();
    super.dispose();
  }

  /// Pins the composer to its last line while text is being added at the end,
  /// so the newest words stay visible once the box is full.
  void _keepComposerEndVisible() {
    final selection = _textController.selection;
    final atEnd = selection.isCollapsed &&
        selection.baseOffset >= _textController.text.length;
    if (!atEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_composerScroll.hasClients) return;
      final maxOffset = _composerScroll.position.maxScrollExtent;
      if (_composerScroll.offset >= maxOffset) return;
      _composerScroll.jumpTo(maxOffset);
    });
  }

  /// Replaces composer text and leaves the caret at the end.
  void _setComposerText(String value) {
    _textController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncMicListening() {
    if (!mounted) return;
    final active = _stt.isCapturing;
    if (_listening != active) {
      setState(() => _listening = active);
    }
  }

  Future<void> _toggleMic() async {
    final app = context.read<AppState>();
    if (_listening || _stt.isListening) {
      _micRequestId++;
      await _stt.stop();
      _syncMicListening();
      return;
    }
    final requestId = ++_micRequestId;

    final ready = await _stt.initialize(
      onStatus: (_) => _syncMicListening(),
      onError: (error) {
        debugPrint('Home STT error: ${error.errorMsg}');
        _syncMicListening();
        if (!mounted) return;
        final msg = error.errorMsg.toLowerCase();
        if (msg.contains('cancelled') ||
            msg.contains('no_match') ||
            msg.contains('speech_timeout') ||
            msg.contains('error_client')) {
          return;
        }
        final text = msg.contains('permission')
            ? AppStrings.microphoneDenied(app.language)
            : msg.contains('pack')
            ? AppStrings.speechPackFailed(app.language)
            : null;
        if (text == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      },
    );

    if (requestId != _micRequestId) return;
    if (!ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.microphoneDenied(app.language))),
      );
      return;
    }

    _micSessionPrefix = _textController.text;
    if (_micSessionPrefix.isNotEmpty && !_micSessionPrefix.endsWith(' ')) {
      _micSessionPrefix = '$_micSessionPrefix ';
    }
    _micSessionWords = '';

    final locale = await _stt.resolveLocale(app.language);
    if (!mounted || requestId != _micRequestId) return;

    final started = await _stt.startListening(
      localeId: locale,
      onResult: (words, _) {
        if (requestId != _micRequestId || !mounted) return;
        final nextWords = words.trim();
        if (nextWords.isEmpty) return;
        if (_micSessionWords.isNotEmpty &&
            nextWords.length < _micSessionWords.length &&
            !_micSessionWords.toLowerCase().startsWith(nextWords.toLowerCase())) {
          return;
        }
        _micSessionWords = nextWords;
        final composed =
            '$_micSessionPrefix${ProfanityFilter.mask(_micSessionWords)}';
        if (_textController.text == composed) return;
        _textController.value = TextEditingValue(
          text: composed,
          selection: TextSelection.collapsed(offset: composed.length),
        );
      },
    );
    if (requestId != _micRequestId) {
      await _stt.stop();
      return;
    }
    _syncMicListening();
    if (!started && mounted) {
      setState(() => _listening = false);
    }
  }

  void _clearComposer() {
    _textController.clear();
    _undoStack
      ..clear()
      ..add('');
    if (_composerScroll.hasClients) _composerScroll.jumpTo(0);
    setState(() => _attachedImagePath = null);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickMedia(
      maxWidth: 900,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _attachedImagePath = file.path);
    }
  }

  void _appendPhrase(String text, {bool speak = false, int? phraseId}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _textController.text.trim();
    _setComposerText(current.isEmpty ? trimmed : '$current $trimmed');
    // A card tap is a use — vocabulary growth counts taps, not only spoken audio.
    unawaited(context.read<AppState>().recordHistory(trimmed));
    if (speak) {
      speakWithFeedback(
        context,
        trimmed,
        phraseId: phraseId,
      );
    }
  }

  Future<void> _refresh() async {
    await context.read<AppState>().refreshLearnerCollections();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final parentCategory = app.selectedTopLevelCategory;
    final headerLabel = app.showingSubcategoryPicker
        ? (parentCategory != null
            ? app.localizedCategoryName(parentCategory)
            : AppStrings.customCategory(lang))
        : (app.selectedCategory != null
            ? app.localizedCategoryName(app.selectedCategory!)
            : AppStrings.customCategory(lang));
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

    return PopScope(
      canPop: app.selectedSubcategoryKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        app.clearSubcategorySelection();
      },
      child: LearnerScaffold(
      title: headerLabel,
      titleWidget: SizedBox(
        height: 85,
        child: Center(
          child: Text(
            headerLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: theme.textMain,
            ),
          ),
        ),
      ),
      currentRoute: AppRoute.home,
      headerContentHeight: 85,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      onMicTap: _toggleMic,
      micActive: _listening,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.bgAccent,
        child: CustomScrollView(
          key: ValueKey('home_${lang.name}_${app.languageRevision}'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (app.showingSubcategoryPicker)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg)
                    .copyWith(bottom: AppSpacing.xxl),
                sliver: SliverGrid(
                  key: ValueKey(
                    'subcats_${lang.name}_${app.languageRevision}_${app.selectedCategoryKey}',
                  ),
                  gridDelegate: AppSpacing.categoryGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final sub = app.subcategoriesForSelected[i];
                      return CategoryGridCard(
                        category: sub,
                        label: app.localizedCategoryName(sub),
                        onTap: () => app.selectSubcategory(sub.key),
                      );
                    },
                    childCount: app.subcategoriesForSelected.length,
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: PanelCard(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.undo_rounded, size: 22),
                        onPressed: _undoStack.length <= 1
                            ? null
                            : () {
                                _undoStack.removeLast();
                                _setComposerText(_undoStack.last);
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
                          _clearComposer();
                        },
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: ColoredBox(
                            color: Color.alphaBlend(
                              Colors.white.withValues(alpha: 0.32),
                              theme.bgLight.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.34),
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.18),
                                ],
                                stops: const [0, 0.3, 0.66, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 1.6,
                              sigmaY: 1.6,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 2.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_attachedImagePath != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  8,
                                  8,
                                  8,
                                  0,
                                ),
                                child: ComposerAttachmentPreview(
                                  path: _attachedImagePath!,
                                  theme: theme,
                                  onRemove: () => setState(
                                    () => _attachedImagePath = null,
                                  ),
                                ),
                              ),
                            TextField(
                              controller: _textController,
                              scrollController: _composerScroll,
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
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    _attachedImagePath != null
                                        ? 0
                                        : AppSpacing.radiusMd,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
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
                          FilledButton.icon(
                            onPressed: _pickImage,
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              backgroundColor: Colors.white,
                              foregroundColor: theme.bgAccent,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                            ),
                            icon: Icon(
                              Icons.perm_media_rounded,
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
                            onPressed: app.showingSubcategoryPicker
                                ? null
                                : () async {
                              final text = _textController.text.trim();
                              if (text.isEmpty) return;
                              final image = _attachedImagePath;
                              _clearComposer();
                              await app.addPhrase(text, imagePath: image);
                            },
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              backgroundColor: theme.bgAccent,
                              foregroundColor: Colors.white,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
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
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(
                        AppStrings.play(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => app.pauseSpeech(),
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.pause_rounded, size: 16),
                      label: Text(
                        AppStrings.pause(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg)
                    .copyWith(bottom: AppSpacing.xxl),
                sliver: SliverGrid(
                  key: ValueKey(
                    'phrases_${lang.name}_${app.languageRevision}_${app.effectivePhraseCategoryKey}',
                  ),
                  gridDelegate: AppSpacing.phraseGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final phrase = app.phrasesForCategory[i];
                      return PhraseCard(
                        key: ValueKey('phrase_${phrase.id}'),
                        phrase: phrase,
                        dense: denseGrid,
                        isFavorite: app.isFavorite(phrase),
                        onTap: () =>
                            _appendPhrase(app.localizedPhraseText(phrase)),
                        onSpeak: () => _appendPhrase(
                          app.localizedPhraseText(phrase),
                          speak: true,
                          phraseId: phrase.id,
                        ),
                        onFavorite: () => app.toggleFavorite(phrase),
                        onView: () => ViewPhraseDialog.show(
                          context,
                          phrase: phrase,
                          displayText: app.localizedPhraseText(phrase),
                        ),
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
                              title: const Text('Are you sure?'),
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
                          if (confirm == true) {
                            final wasFavorite = app.isFavorite(phrase);
                            await app.deletePhrase(phrase);
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            final snackBar = messenger.showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 5),
                                content: const Text(
                                  'Deleting phrase in 5 seconds',
                                ),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    unawaited(
                                      app.restorePhrase(
                                        phrase,
                                        restoreFavorite: wasFavorite,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                            await Future<void>.delayed(
                              const Duration(seconds: 5),
                            );
                            snackBar.close();
                          }
                        },
                      );
                    },
                    childCount: app.phrasesForCategory.length,
                    // Keep built non-Home video cards alive while scrolling.
                    // Home cards keep-alive only after their video loads.
                    addAutomaticKeepAlives: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
