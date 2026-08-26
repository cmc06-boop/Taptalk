import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/history_model.dart';
import '../data/repositories/app_repository.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _slideOutDuration = Duration(milliseconds: 320);

  List<HistoryModel> _items = [];
  final Set<int> _slidingOutIds = {};
  bool _clearing = false;

  /// Learner history shows phrase taps only — not internal app-session markers.
  List<HistoryModel> _visibleHistory(List<HistoryModel> source) {
    return source
        .where(
          (item) => !AppRepository.isAppSessionMarker(
            categoryKey: item.categoryKey,
            phraseText: item.text,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _items = _visibleHistory(context.read<AppState>().history);
  }

  void _mergeNewHistory(List<HistoryModel> source) {
    if (_clearing) return;
    final visible = _visibleHistory(source);
    if (visible.isEmpty) {
      if (_items.isNotEmpty) {
        setState(() => _items = []);
      }
      return;
    }
    final hasNewEntries =
        visible.length > _items.length ||
        (_items.isNotEmpty && visible.first.id != _items.first.id);
    if (hasNewEntries) {
      setState(() => _items = visible);
    }
  }

  void _removeItem(HistoryModel item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index < 0) return;
    setState(() => _items.removeAt(index));
    context.read<AppState>().deleteHistoryItem(item);
  }

  Future<void> _refresh() async {
    await context.read<AppState>().refreshLearnerCollections();
    if (!mounted) return;
    setState(() {
      _items = _visibleHistory(context.read<AppState>().history);
    });
  }

  Future<void> _clearAll(AppLanguage lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.clearAllHistoryConfirm(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.clearAll(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final toClear = List<HistoryModel>.from(_items);
    if (toClear.isEmpty) return;
    _clearing = true;
    setState(() {
      _slidingOutIds
        ..clear()
        ..addAll(toClear.map((e) => e.id));
    });
    await Future<void>.delayed(_slideOutDuration);
    if (!mounted) return;
    setState(() {
      _items = [];
      _slidingOutIds.clear();
      _clearing = false;
    });
    await context.read<AppState>().clearAllHistory();
  }

  String _categoryLabel(AppState app, HistoryModel item) {
    if (item.isLessonEntry) {
      return app.localizedContent(item.lessonContext!.className);
    }
    var categoryLabel = item.categoryKey;
    for (final cat in app.categories) {
      if (cat.key == item.categoryKey) {
        categoryLabel = app.localizedCategoryName(cat);
        break;
      }
    }
    if (categoryLabel == item.categoryKey) {
      categoryLabel = app.localizedCategoryKey(item.categoryKey);
    }
    return categoryLabel;
  }

  Widget _buildCard(HistoryModel item, AppLanguage lang) {
    final app = context.read<AppState>();
    final theme = app.theme;
    final fmt = DateFormat('h:mm a');

    return _HistoryCard(
      key: ValueKey('history_${item.id}_${lang.name}_${app.languageRevision}'),
      item: item,
      formattedTime: fmt.format(item.createdAt),
      theme: theme,
      onRemove: () => _removeItem(item),
      onSpeak: () => speakWithFeedback(
        context,
        item.text,
        record: false,
        categoryKey: item.categoryKey,
      ),
      categoryLabelFor: _categoryLabel,
    );
  }

  List<Widget> _buildDatedHistory(AppLanguage lang, TapTalkThemeToken theme) {
    final widgets = <Widget>[];
    DateTime? previousDay;
    final dateFormat = DateFormat('MMMM d, y');

    for (final item in _items) {
      final day = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      if (previousDay == null || day != previousDay) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: AppSpacing.sm));
        }
        final dateLabel = Text(
          dateFormat.format(day),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: theme.textMain,
          ),
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: previousDay == null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: dateLabel),
                      TextButton(
                        onPressed: () => _clearAll(lang),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.bgAccent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppStrings.clearAll(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.bgAccent,
                          ),
                        ),
                      ),
                    ],
                  )
                : dateLabel,
          ),
        );
        previousDay = day;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _HistorySlideOut(
            sliding: _slidingOutIds.contains(item.id),
            duration: _slideOutDuration,
            child: _buildCard(item, lang),
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    _mergeNewHistory(app.history);

    return LearnerScaffold(
      title: AppStrings.history(lang),
      titleWidget: SizedBox(
        height: 85,
        child: Center(
          child: Text(
            AppStrings.history(lang),
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
      currentRoute: AppRoute.history,
      headerContentHeight: 85,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.bgAccent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (_items.isEmpty)
              SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 0.38,
                child: Center(
                  child: Text(
                    AppStrings.emptyHistory(lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: theme.textMain.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              )
            else ...[
              ..._buildDatedHistory(lang, theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistorySlideOut extends StatelessWidget {
  const _HistorySlideOut({
    required this.sliding,
    required this.duration,
    required this.child,
  });

  final bool sliding;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSlide(
        offset: sliding ? const Offset(1.08, 0) : Offset.zero,
        duration: duration,
        curve: Curves.easeInCubic,
        child: child,
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
    required this.item,
    required this.formattedTime,
    required this.theme,
    required this.onRemove,
    required this.onSpeak,
    required this.categoryLabelFor,
  });

  final HistoryModel item;
  final String formattedTime;
  final TapTalkThemeToken theme;
  final VoidCallback onRemove;
  final VoidCallback onSpeak;
  final String Function(AppState app, HistoryModel item) categoryLabelFor;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final phraseText = app.localizedPhrase(item.text, item.categoryKey);
    final categoryLabel = categoryLabelFor(app, item);
    final lessonClassName = item.lessonContext == null
        ? null
        : app.localizedContent(item.lessonContext!.className);
    final lessonTitle = item.lessonContext == null
        ? null
        : app.localizedContent(item.lessonContext!.lessonTitle);

    return Dismissible(
      key: ValueKey('dismiss_history_${item.id}'),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.accentEmphasis,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFullInfo(
            context,
            phraseText: phraseText,
            chipLabel: item.isLessonEntry ? lessonClassName! : categoryLabel,
            lessonTitle: lessonTitle,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: theme.bgMid.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: theme.textMain.withValues(alpha: 0.07),
                  blurRadius: 2,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _categoryChip(
                        item.isLessonEntry ? lessonClassName! : categoryLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formattedTime,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.textMain.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  phraseText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textMain,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: theme.bgAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showFullInfo(
    BuildContext context, {
    required String phraseText,
    required String chipLabel,
    required String? lessonTitle,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _categoryChip(chipLabel),
                    const Spacer(),
                    Text(
                      formattedTime,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textMain.withValues(alpha: 0.58),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.textMain.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                if (item.isLessonEntry &&
                    lessonTitle != null &&
                    item.text.trim() !=
                        item.lessonContext!.lessonTitle.trim()) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    lessonTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textMain.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Text(
                      phraseText,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.textMain,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
