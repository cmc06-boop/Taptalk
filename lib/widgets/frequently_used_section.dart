import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/phrase_usage_stat.dart';
import '../data/repositories/app_repository.dart';

class FrequentlyUsedSection extends StatefulWidget {
  const FrequentlyUsedSection({
    super.key,
    required this.stats,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
    required this.labelForPhrase,
    required this.reloadNonce,
    this.allowedCategoryKeys,
  });

  final List<PhraseUsageStat> stats;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;
  final String Function(PhraseUsageStat stat) labelForPhrase;
  final int reloadNonce;
  final Set<String>? allowedCategoryKeys;

  static const previewPhraseCount = 5;

  @override
  State<FrequentlyUsedSection> createState() => _FrequentlyUsedSectionState();
}

class _FrequentlyUsedSectionState extends State<FrequentlyUsedSection> {
  String? _selectedCategoryKey;
  bool _dropdownOpen = false;

  bool _isAllowedCategory(String categoryKey) {
    if (!AppRepository.isPersonalCategoryKey(categoryKey)) return false;
    final allowed = widget.allowedCategoryKeys;
    if (allowed == null || allowed.isEmpty) return true;
    return allowed.contains(AppRepository.normalizeCategoryKey(categoryKey));
  }

  List<PhraseUsageStat> get _personalStats => widget.stats
      .where((s) => _isAllowedCategory(s.categoryKey))
      .toList();

  Map<String, List<PhraseUsageStat>> _groupByCategory(
    List<PhraseUsageStat> stats,
  ) {
    final grouped = <String, List<PhraseUsageStat>>{};
    for (final stat in stats) {
      grouped.putIfAbsent(stat.categoryKey, () => []).add(stat);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.text.compareTo(b.text);
      });
    }
    return grouped;
  }

  List<String> _sortedCategoryKeys(Map<String, List<PhraseUsageStat>> grouped) {
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final maxA = grouped[a]!.fold<int>(0, (m, s) => math.max(m, s.count));
        final maxB = grouped[b]!.fold<int>(0, (m, s) => math.max(m, s.count));
        final byUsage = maxB.compareTo(maxA);
        if (byUsage != 0) return byUsage;
        return widget
            .labelForCategory(a)
            .compareTo(widget.labelForCategory(b));
      });
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _syncSelectedCategory();
  }

  @override
  void didUpdateWidget(covariant FrequentlyUsedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadNonce != widget.reloadNonce ||
        oldWidget.stats != widget.stats) {
      _syncSelectedCategory();
    }
  }

  void _syncSelectedCategory() {
    final grouped = _groupByCategory(_personalStats);
    final keys = _sortedCategoryKeys(grouped);
    if (keys.isEmpty) {
      _selectedCategoryKey = null;
      return;
    }
    if (_selectedCategoryKey == null ||
        !keys.contains(_selectedCategoryKey)) {
      _selectedCategoryKey = keys.first;
    }
  }

  Future<void> _showAllPhrasesSheet({
    required Map<String, List<PhraseUsageStat>> grouped,
    required List<String> categoryKeys,
    required String selectedKey,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllFrequentlyUsedSheet(
        grouped: grouped,
        categoryKeys: categoryKeys,
        initialCategoryKey: selectedKey,
        theme: widget.theme,
        lang: widget.lang,
        labelForCategory: widget.labelForCategory,
        labelForPhrase: widget.labelForPhrase,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedCategoryKey = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;
    final personalStats = _personalStats;

    if (personalStats.isEmpty) {
      return Text(
        AppStrings.noPhraseUsage(lang),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: theme.textMain.withValues(alpha: 0.7),
        ),
      );
    }

    final grouped = _groupByCategory(personalStats);
    final categoryKeys = _sortedCategoryKeys(grouped);
    final selectedKey = _selectedCategoryKey ?? categoryKeys.first;
    final selectedItems = grouped[selectedKey] ?? const [];
    final previewItems = selectedItems
        .take(FrequentlyUsedSection.previewPhraseCount)
        .toList();
    final hasMore =
        selectedItems.length > FrequentlyUsedSection.previewPhraseCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.frequentlyUsedSubtitle(lang),
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: theme.textMain.withValues(alpha: 0.62),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _InlineDropdownField<String>(
          label: AppStrings.selectCategory(lang),
          value: widget.labelForCategory(selectedKey),
          options: categoryKeys,
          optionLabel: widget.labelForCategory,
          selected: selectedKey,
          isOpen: _dropdownOpen,
          theme: theme,
          onToggle: () => setState(() => _dropdownOpen = !_dropdownOpen),
          onSelected: (key) {
            setState(() {
              _selectedCategoryKey = key;
              _dropdownOpen = false;
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (selectedItems.isEmpty)
          Text(
            AppStrings.noPhrasesInSelectedCategory(lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.textMain.withValues(alpha: 0.65),
            ),
          )
        else ...[
          for (final stat in previewItems)
            _PhraseStatCard(
              theme: theme,
              lang: lang,
              phrase: widget.labelForPhrase(stat),
              count: stat.count,
            ),
          if (hasMore) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showAllPhrasesSheet(
                  grouped: grouped,
                  categoryKeys: categoryKeys,
                  selectedKey: selectedKey,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppStrings.seeAll(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.bgAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _AllFrequentlyUsedSheet extends StatefulWidget {
  const _AllFrequentlyUsedSheet({
    required this.grouped,
    required this.categoryKeys,
    required this.initialCategoryKey,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
    required this.labelForPhrase,
  });

  final Map<String, List<PhraseUsageStat>> grouped;
  final List<String> categoryKeys;
  final String initialCategoryKey;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;
  final String Function(PhraseUsageStat stat) labelForPhrase;

  @override
  State<_AllFrequentlyUsedSheet> createState() =>
      _AllFrequentlyUsedSheetState();
}

class _AllFrequentlyUsedSheetState extends State<_AllFrequentlyUsedSheet> {
  late String _selectedCategoryKey;
  bool _dropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryKey = widget.categoryKeys.contains(widget.initialCategoryKey)
        ? widget.initialCategoryKey
        : widget.categoryKeys.first;
  }

  List<PhraseUsageStat> get _selectedItems =>
      widget.grouped[_selectedCategoryKey] ?? const [];

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;
    final items = _selectedItems;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textMain.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.allFrequentlyUsedTitle(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedCategoryKey),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.textMain.withValues(alpha: 0.55),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9EEF2)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InlineDropdownField<String>(
                          label: AppStrings.selectCategory(lang),
                          value: widget.labelForCategory(_selectedCategoryKey),
                          options: widget.categoryKeys,
                          optionLabel: widget.labelForCategory,
                          selected: _selectedCategoryKey,
                          isOpen: _dropdownOpen,
                          theme: theme,
                          onToggle: () =>
                              setState(() => _dropdownOpen = !_dropdownOpen),
                          onSelected: (key) {
                            setState(() {
                              _selectedCategoryKey = key;
                              _dropdownOpen = false;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Text(
                              AppStrings.noPhrasesInSelectedCategory(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: theme.textMain.withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        else
                          for (final stat in items)
                            _PhraseStatCard(
                              theme: theme,
                              lang: lang,
                              phrase: widget.labelForPhrase(stat),
                              count: stat.count,
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhraseStatCard extends StatelessWidget {
  const _PhraseStatCard({
    required this.theme,
    required this.lang,
    required this.phrase,
    required this.count,
  });

  static const _cardRadius = 14.0;

  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String phrase;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.bgMid.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              phrase,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textMain,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.bgAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppStrings.timesUsed(count, lang),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.bgAccent,
              ),
            ),
          ),
        ],
      ),
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
    const openFieldRadius = BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    );
    const menuRadius = BorderRadius.only(
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
                  color: isOpen
                      ? theme.bgAccent.withValues(alpha: 0.35)
                      : _borderColor,
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
                    constraints: const BoxConstraints(maxHeight: 220),
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
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.bgAccent
                                          : theme.textMain,
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
