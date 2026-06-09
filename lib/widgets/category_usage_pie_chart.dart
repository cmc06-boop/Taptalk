import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/category_model.dart';
import '../data/models/vocabulary_growth_summary.dart';
import '../data/repositories/app_repository.dart';

int _totalCategoryUsage(List<CategoryVocabularySlice> slices) =>
    slices.fold(0, (sum, slice) => sum + slice.usageCount);

/// Visual slice weights — zero-usage categories keep a small slice so they stay visible.
List<double> _categorySliceValues(List<CategoryVocabularySlice> slices) {
  if (slices.isEmpty) return const [];
  const minWeight = 1.0;
  return slices
      .map((slice) => math.max(slice.usageCount.toDouble(), minWeight))
      .toList();
}

class CategoryUsagePieChart extends StatelessWidget {
  const CategoryUsagePieChart({
    super.key,
    required this.slices,
    required this.allCategories,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
  });

  final List<CategoryVocabularySlice> slices;
  final List<CategoryModel> allCategories;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;

  static const slicePalette = [
    Color(0xFF4A90D9),
    Color(0xFF50C878),
    Color(0xFFE87C4C),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFF1ABC9C),
    Color(0xFFF1C40F),
    Color(0xFF34495E),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
  ];

  static void showInfoDialog(
    BuildContext context, {
    required AppLanguage lang,
    required TapTalkThemeToken theme,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppStrings.categoriesUsedInfoTitle(lang),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.textMain,
          ),
        ),
        content: Text(
          AppStrings.categoriesUsedInfoBody(lang),
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.45,
            color: theme.textMain.withValues(alpha: 0.82),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.ok(lang),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: theme.bgAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Color> sliceColors(int count) {
    return List.generate(math.max(count, 1), (i) {
      return slicePalette[i % slicePalette.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullSlices = AppRepository.buildCategorySlicesForAllCategories(
      categories: allCategories,
      usageSlices: slices,
    );

    if (fullSlices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            AppStrings.noVocabularyData(lang),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.textMain.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    return _InteractiveCategoryDonut(
      slices: fullSlices,
      colors: sliceColors(fullSlices.length),
      theme: theme,
      lang: lang,
      labelForCategory: labelForCategory,
    );
  }
}

class _CategoryLegendLayout {
  const _CategoryLegendLayout({
    required this.columns,
    required this.previewItemCount,
  });

  final int columns;
  final int previewItemCount;

  static const _previewRows = 2;
  static const _columnSpacing = AppSpacing.sm;
  static const _cellHorizontalInset = 28.0;
  static const _minCellWidth = 68.0;

  static TextStyle labelStyle(Color textColor) => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.15,
      );

  static TextStyle detailStyle(Color textColor) => GoogleFonts.poppins(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: textColor.withValues(alpha: 0.55),
        height: 1.15,
      );

  static _CategoryLegendLayout forWidth({
    required double width,
    required List<CategoryVocabularySlice> slices,
    required String Function(String categoryKey) labelForCategory,
    required int totalUsage,
    required AppLanguage lang,
    required Color textColor,
  }) {
    final labels = <String>[];
    final details = <String>[];
    for (final slice in slices) {
      labels.add(labelForCategory(slice.categoryKey));
      details.add(
        AppStrings.categoryLegendDetail(
          wordCount: slice.wordCount,
          usageCount: slice.usageCount,
          totalUsage: totalUsage,
          lang: lang,
        ),
      );
    }

    final labelTextStyle = labelStyle(textColor);
    final detailTextStyle = detailStyle(textColor);
    final columns = _columnsForWidth(
      width: width,
      itemCount: slices.length,
      labels: labels,
      details: details,
      labelStyle: labelTextStyle,
      detailStyle: detailTextStyle,
    );
    final previewItemCount = math.min(slices.length, columns * _previewRows);

    return _CategoryLegendLayout(
      columns: columns,
      previewItemCount: previewItemCount,
    );
  }

  static int _columnsForWidth({
    required double width,
    required int itemCount,
    required List<String> labels,
    required List<String> details,
    required TextStyle labelStyle,
    required TextStyle detailStyle,
  }) {
    if (itemCount <= 0 || width <= 0) return 1;

    final maxColumns = itemCount;
    for (var cols = maxColumns; cols >= 1; cols--) {
      final cellWidth = (width - _columnSpacing * (cols - 1)) / cols;
      if (cellWidth < _minCellWidth) continue;

      final textMaxWidth = cellWidth - _cellHorizontalInset;
      if (textMaxWidth <= 0) continue;

      if (_allLinesFit(
        maxWidth: textMaxWidth,
        labels: labels,
        details: details,
        labelStyle: labelStyle,
        detailStyle: detailStyle,
      )) {
        return cols;
      }
    }

    return 1;
  }

  static bool _allLinesFit({
    required double maxWidth,
    required List<String> labels,
    required List<String> details,
    required TextStyle labelStyle,
    required TextStyle detailStyle,
  }) {
    for (var i = 0; i < labels.length; i++) {
      if (!_lineFits(labels[i], labelStyle, maxWidth)) return false;
      if (!_lineFits(details[i], detailStyle, maxWidth)) return false;
    }
    return true;
  }

  static bool _lineFits(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }
}

class _InteractiveCategoryDonut extends StatefulWidget {
  const _InteractiveCategoryDonut({
    required this.slices,
    required this.colors,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
  });

  final List<CategoryVocabularySlice> slices;
  final List<Color> colors;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;

  @override
  State<_InteractiveCategoryDonut> createState() =>
      _InteractiveCategoryDonutState();
}

class _InteractiveCategoryDonutState extends State<_InteractiveCategoryDonut> {
  static const _chartSize = 118.0;
  static const _strokeWidth = 18.0;

  int? _selectedIndex;

  int get _totalUsage => _totalCategoryUsage(widget.slices);

  void _selectIndex(int? index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  Future<void> _showAllCategoriesSheet() async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllCategoriesSheet(
        slices: widget.slices,
        colors: widget.colors,
        theme: widget.theme,
        lang: widget.lang,
        labelForCategory: widget.labelForCategory,
        totalUsage: _totalUsage,
        selectedIndex: _selectedIndex,
      ),
    );
    if (!mounted) return;
    setState(() => _selectedIndex = selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;
    final slices = widget.slices;
    final totalUsage = _totalUsage;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _CategoryLegendLayout.forWidth(
          width: constraints.maxWidth,
          slices: slices,
          labelForCategory: widget.labelForCategory,
          totalUsage: totalUsage,
          lang: lang,
          textColor: theme.textMain,
        );
        final previewIndices =
            List.generate(layout.previewItemCount, (index) => index);
        final hasMore = slices.length > layout.previewItemCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _CategoryDonutChart(
                size: _chartSize,
                strokeWidth: _strokeWidth,
                slices: slices,
                sliceValues: _categorySliceValues(slices),
                colors: widget.colors,
                theme: theme,
                lang: lang,
                selectedIndex: _selectedIndex,
                onSliceTap: _selectIndex,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CategoriesLegendGrid(
              slices: slices,
              colors: widget.colors,
              theme: theme,
              lang: lang,
              labelForCategory: widget.labelForCategory,
              totalUsage: totalUsage,
              indices: previewIndices,
              columns: layout.columns,
              selectedIndex: _selectedIndex,
              onSelect: _selectIndex,
            ),
            if (hasMore) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showAllCategoriesSheet,
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
        );
      },
    );
  }
}

class _AllCategoriesSheet extends StatefulWidget {
  const _AllCategoriesSheet({
    required this.slices,
    required this.colors,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
    required this.totalUsage,
    required this.selectedIndex,
  });

  final List<CategoryVocabularySlice> slices;
  final List<Color> colors;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;
  final int totalUsage;
  final int? selectedIndex;

  @override
  State<_AllCategoriesSheet> createState() => _AllCategoriesSheetState();
}

class _AllCategoriesSheetState extends State<_AllCategoriesSheet> {
  static const _chartSize = 132.0;
  static const _strokeWidth = 20.0;

  late int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  void _close() {
    Navigator.pop(context, _selectedIndex);
  }

  void _selectIndex(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;
    final slices = widget.slices;
    final allIndices = List.generate(slices.length, (index) => index);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;

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
                          AppStrings.allCategoriesTitle(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _close,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final layout = _CategoryLegendLayout.forWidth(
                        width: constraints.maxWidth - (AppSpacing.md * 2),
                        slices: slices,
                        labelForCategory: widget.labelForCategory,
                        totalUsage: widget.totalUsage,
                        lang: lang,
                        textColor: theme.textMain,
                      );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _CategoryDonutChart(
                                size: _chartSize,
                                strokeWidth: _strokeWidth,
                                slices: slices,
                                sliceValues: _categorySliceValues(slices),
                                colors: widget.colors,
                                theme: theme,
                                lang: lang,
                                selectedIndex: _selectedIndex,
                                onSliceTap: _selectIndex,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _CategoriesLegendGrid(
                              slices: slices,
                              colors: widget.colors,
                              theme: theme,
                              lang: lang,
                              labelForCategory: widget.labelForCategory,
                              totalUsage: widget.totalUsage,
                              indices: allIndices,
                              columns: layout.columns,
                              selectedIndex: _selectedIndex,
                              onSelect: _selectIndex,
                            ),
                          ],
                        ),
                      );
                    },
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

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({
    required this.size,
    required this.strokeWidth,
    required this.slices,
    required this.sliceValues,
    required this.colors,
    required this.theme,
    required this.lang,
    required this.selectedIndex,
    required this.onSliceTap,
  });

  final double size;
  final double strokeWidth;
  final List<CategoryVocabularySlice> slices;
  final List<double> sliceValues;
  final List<Color> colors;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final int? selectedIndex;
  final ValueChanged<int> onSliceTap;

  int? _sliceIndexAt(Offset local) {
    final count = sliceValues.length;
    if (count <= 0) return null;

    final center = Offset(size / 2, size / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final radius = size / 2 - strokeWidth / 2;
    final inner = radius - strokeWidth / 2;
    final outer = radius + strokeWidth / 2;
    if (dist < inner || dist > outer) return null;

    var fromTop = math.atan2(dy, dx) + math.pi / 2;
    if (fromTop < 0) fromTop += 2 * math.pi;

    final total = sliceValues.fold(0.0, (sum, value) => sum + value);
    if (total <= 0) {
      final sweep = 2 * math.pi / count;
      return (fromTop / sweep).floor().clamp(0, count - 1);
    }

    final angle = fromTop / (2 * math.pi);
    var cumulative = 0.0;
    for (var i = 0; i < sliceValues.length; i++) {
      cumulative += sliceValues[i] / total;
      if (angle <= cumulative || i == sliceValues.length - 1) return i;
    }
    return count - 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final index = _sliceIndexAt(details.localPosition);
        if (index == null) return;
        onSliceTap(index);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            values: sliceValues,
            colors: colors,
            strokeWidth: strokeWidth,
            centerLabel: '${slices.length}',
            centerSubLabel: AppStrings.categoryCountLabel(lang),
            labelColor: theme.textMain,
            selectedIndex: selectedIndex,
            dimUnselected: selectedIndex != null,
          ),
        ),
      ),
    );
  }
}

class _CategoriesLegendGrid extends StatelessWidget {
  const _CategoriesLegendGrid({
    required this.slices,
    required this.colors,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
    required this.totalUsage,
    required this.indices,
    required this.columns,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<CategoryVocabularySlice> slices;
  final List<Color> colors;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;
  final int totalUsage;
  final List<int> indices;
  final int columns;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < indices.length; i += columns) {
      final rowIndices = indices.sublist(
        i,
        math.min(i + columns, indices.length),
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + columns < indices.length ? AppSpacing.sm : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < columns; col++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: col < columns - 1 ? AppSpacing.sm : 0,
                    ),
                    child: col < rowIndices.length
                        ? _LegendChip(
                            color: colors[rowIndices[col] % colors.length],
                            label: labelForCategory(
                              slices[rowIndices[col]].categoryKey,
                            ),
                            detailLine: AppStrings.categoryLegendDetail(
                              wordCount: slices[rowIndices[col]].wordCount,
                              usageCount: slices[rowIndices[col]].usageCount,
                              totalUsage: totalUsage,
                              lang: lang,
                            ),
                            textColor: theme.textMain,
                            selected: selectedIndex == rowIndices[col],
                            onTap: () => onSelect(rowIndices[col]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.detailLine,
    required this.textColor,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final String detailLine;
  final Color textColor;
  final bool selected;
  final VoidCallback onTap;

  static const _cellPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.xs + 2,
  );

  @override
  Widget build(BuildContext context) {
    final labelStyle = _CategoryLegendLayout.labelStyle(textColor);
    final detailStyle = _CategoryLegendLayout.detailStyle(textColor);

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScaledLegendLine(text: label, style: labelStyle),
              _ScaledLegendLine(
                text: detailLine,
                style: detailStyle,
              ),
            ],
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $detailLine.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: _cellPadding,
          decoration: selected
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                )
              : null,
          child: content,
        ),
      ),
    );
  }
}

class _ScaledLegendLine extends StatelessWidget {
  const _ScaledLegendLine({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
    required this.centerLabel,
    required this.centerSubLabel,
    required this.labelColor,
    this.selectedIndex,
    this.dimUnselected = false,
  });

  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;
  final String centerLabel;
  final String centerSubLabel;
  final Color labelColor;
  final int? selectedIndex;
  final bool dimUnselected;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;

    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = labelColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    } else {
      var start = -math.pi / 2;
      for (var i = 0; i < values.length; i++) {
        final sweep = (values[i] / total) * 2 * math.pi;
        final isSelected = selectedIndex == i;
        final isDimmed = dimUnselected && selectedIndex != null && !isSelected;
        final sliceColor = isDimmed
            ? colors[i % colors.length].withValues(alpha: 0.28)
            : colors[i % colors.length];
        final paint = Paint()
          ..color = sliceColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? strokeWidth + 3 : strokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
        start += sweep;
      }
    }

    final titleTp = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(
      canvas,
      Offset(center.dx - titleTp.width / 2, center.dy - titleTp.height / 2 - 3),
    );

    final subTp = TextPainter(
      text: TextSpan(
        text: centerSubLabel,
        style: TextStyle(
          color: labelColor.withValues(alpha: 0.55),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(
      canvas,
      Offset(center.dx - subTp.width / 2, center.dy + 5),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.dimUnselected != dimUnselected;
  }
}
