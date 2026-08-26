import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/category_model.dart';
import '../providers/app_state.dart';
import 'compact_popup_menu.dart';

/// Maps a category key to its custom card image path under assets/images/Category Cards/.
/// Returns null if no custom image exists for that key.
String? _categoryCardImagePath(String key) {
  const map = <String, String>{
    'emotions': 'assets/images/Category Cards/Emotions.png',
    'food': 'assets/images/Category Cards/Food.png',
    'drinks': 'assets/images/Category Cards/Drinks.png',
    'school': 'assets/images/Category Cards/School.png',
    'questions': 'assets/images/Category Cards/Questions.png',
    'health_safety': 'assets/images/Category Cards/Health & Safety.png',
    'family': 'assets/images/Category Cards/Family.png',
    'activities': 'assets/images/Category Cards/Activities.png',
    'greetings': 'assets/images/Category Cards/Greetings.png',
    'animals': 'assets/images/Category Cards/Animals.png',
    'colors': 'assets/images/Category Cards/Colors.png',
    'places': 'assets/images/Category Cards/Places.png',
    'transportation': 'assets/images/Category Cards/Transportation.png',
    'technology': 'assets/images/Category Cards/Technology.png',
    'alphabets': 'assets/images/Category Cards/Alphabets.png',
    'body_parts': 'assets/images/Category Cards/Body Parts.png',
    'dates': 'assets/images/Category Cards/Dates.png',
    'home': 'assets/images/Category Cards/Home .png',
    'numbers': 'assets/images/Category Cards/Numbers.png',
    'phrases': 'assets/images/Category Cards/Phrases.png',
    'dates_days': 'assets/images/Category Cards/Days.png',
    'dates_months': 'assets/images/Category Cards/Months.png',
    'food_fruits': 'assets/images/Category Cards/Fruits.png',
    'food_vegetables': 'assets/images/Category Cards/Vegetable.png',
    'food_dessert': 'assets/images/Category Cards/Dessert.png',
    'food_meals': 'assets/images/Category Cards/Meals.png',
    'food_snacks': 'assets/images/Category Cards/Snack.png',
    'food_bread': 'assets/images/Category Cards/Bread & Pastries.png',
    'food_eggs': 'assets/images/Category Cards/Eggs.png',
    'food_meat': 'assets/images/Category Cards/Meat.png',
    'food_seafood': 'assets/images/Category Cards/Seafood.png',
    'drinks_hot': 'assets/images/Category Cards/Hot Drinks.png',
    'drinks_cold': 'assets/images/Category Cards/Cold Drinks.png',
    'drinks_water': 'assets/images/Category Cards/Water.png',
    'drinks_soft': 'assets/images/Category Cards/Soft Drinks.png',
    'school_people': 'assets/images/Category Cards/People.png',
    'school_supplies': 'assets/images/Category Cards/School Supplies.png',
    'school_work': 'assets/images/Category Cards/Schoolwork.png',
    'school_subjects': 'assets/images/Category Cards/Subject.png',
  };
  return map[key];
}

/// A category card that mirrors the PhraseCard layout:
/// - Large image fills the top area
/// - Label sits below the image
/// - Tap triggers [onTap]
class CategoryGridCard extends StatelessWidget {
  const CategoryGridCard({
    super.key,
    required this.category,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.onDelete,
    this.onEdit,
    this.selectionMode = false,
    this.multiSelected = false,
    this.onSelectionToggle,
    this.customStyle = false,
  });

  final CategoryModel category;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool selectionMode;
  final bool multiSelected;
  final VoidCallback? onSelectionToggle;
  final bool customStyle;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final imagePath = _categoryCardImagePath(category.key);
    const cardRadius = AppSpacing.radiusLg;
    const edgePad = AppSpacing.sm;

    if (customStyle) {
      return _CustomCategoryCard(
        category: category,
        label: label,
        onTap: selectionMode ? onSelectionToggle : onTap,
        onDelete: selectionMode ? null : onDelete,
        onEdit: selectionMode ? null : onEdit,
        selectionMode: selectionMode,
        selected: multiSelected,
      );
    }

    return Material(
      color: theme.bgMid,
      elevation: 0,
      shadowColor: theme.textMain.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectionMode ? onSelectionToggle : onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.bgMid,
            borderRadius: BorderRadius.circular(cardRadius),
            border: selected
                ? Border.all(color: theme.bgAccent, width: 2.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: selected
                    ? theme.bgAccent.withValues(alpha: 0.28)
                    : theme.textMain.withValues(alpha: 0.10),
                blurRadius: selected ? 16 : 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(edgePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      child: imagePath != null
                          ? Image.asset(
                              imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, e, s) =>
                                  _FallbackIcon(category: category),
                            )
                          : _FallbackIcon(category: category),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                    Expanded(child: Center(child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                        height: 1.12,
                      ),
                    )))),
                    if (selectionMode)
                      Icon(
                        multiSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 21,
                        color: multiSelected ? theme.bgAccent : theme.textMain.withValues(alpha: 0.55),
                      )
                  ],
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

class _CustomCategoryCard extends StatelessWidget {
  const _CustomCategoryCard({
    required this.category,
    required this.label,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.selectionMode,
    required this.selected,
  });

  final CategoryModel category;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final accent = theme.bgAccent;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent,
        Color.alphaBlend(Colors.white.withValues(alpha: 0.24), accent),
      ],
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : accent.withValues(alpha: 0.42),
              width: selected ? 2.5 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              const Positioned.fill(child: _CustomCategoryBubbleDecor()),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 7,
                top: 7,
                child: selectionMode
                    ? Icon(
                        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: Colors.white,
                        size: 25,
                      )
                    : _CategoryMoreButton(onEdit: onEdit, onDelete: onDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryMoreButton extends StatelessWidget {
  const _CategoryMoreButton({this.onEdit, this.onDelete});
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    return CompactPopupMenu(
      vertical: true,
      buttonWidth: 28,
      buttonHeight: 28,
      dotsSize: 18,
      buttonBackground: Colors.white.withValues(alpha: 0.9),
      iconColor: const Color(0xFF5C3D2E),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      actions: [
        if (onEdit != null)
          CompactMenuAction(
            value: 'edit',
            label: AppStrings.edit(lang),
            icon: Icons.edit_outlined,
            color: const Color(0xFF5C3D2E),
          ),
        if (onDelete != null)
          CompactMenuAction(
            value: 'delete',
            label: AppStrings.delete(lang),
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFD64545),
          ),
      ],
    );
  }
}

class _CustomCategoryBubbleDecor extends StatelessWidget {
  const _CustomCategoryBubbleDecor();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        Widget bubble(double size, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        );

        return Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            Positioned(
              right: -width * 0.14,
              top: -height * 0.10,
              child: bubble(width * 0.58, 0.16),
            ),
            Positioned(
              left: -width * 0.18,
              bottom: -height * 0.13,
              child: bubble(width * 0.52, 0.13),
            ),
            Positioned(
              left: width * 0.08,
              top: height * 0.12,
              child: bubble(width * 0.24, 0.18),
            ),
            Positioned(
              right: width * 0.11,
              bottom: height * 0.16,
              child: bubble(width * 0.28, 0.15),
            ),
            Positioned(
              left: width * 0.42,
              top: height * 0.38,
              child: bubble(width * 0.18, 0.12),
            ),
            Positioned(
              right: width * 0.35,
              top: height * 0.08,
              child: bubble(width * 0.11, 0.17),
            ),
            Positioned(
              left: width * 0.18,
              bottom: height * 0.34,
              child: bubble(width * 0.16, 0.14),
            ),
            Positioned(
              right: width * 0.04,
              top: height * 0.46,
              child: bubble(width * 0.15, 0.18),
            ),
            Positioned(
              left: width * 0.54,
              bottom: height * 0.06,
              child: bubble(width * 0.13, 0.16),
            ),
            Positioned(
              left: width * 0.04,
              top: height * 0.48,
              child: bubble(width * 0.10, 0.19),
            ),
            Positioned(
              right: width * 0.25,
              bottom: height * 0.40,
              child: bubble(width * 0.09, 0.13),
            ),
            Positioned(
              left: width * 0.68,
              top: height * 0.22,
              child: bubble(width * 0.08, 0.18),
            ),
          ],
        );
      },
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.category});
  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final color = category.accentColor;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Center(
        child: Icon(category.icon, size: 30, color: color),
      ),
    );
  }
}
