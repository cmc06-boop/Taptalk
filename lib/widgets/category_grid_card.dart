import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../data/models/category_model.dart';
import '../providers/app_state.dart';

/// Maps a category key to its custom card image path under assets/images/Category Cards/.
/// Returns null if no custom image exists for that key.
String? _categoryCardImagePath(String key) {
  const map = <String, String>{
    'food': 'assets/images/Category Cards/Food.png',
    'drinks': 'assets/images/Category Cards/Drinks.png',
    'food_fruits': 'assets/images/Category Cards/Fruits.png',
    'food_vegetables': 'assets/images/Category Cards/Vegetable.png',
    'food_dessert': 'assets/images/Category Cards/Dessert.png',
    'food_meals': 'assets/images/Category Cards/Meals.png',
    'drinks_hot': 'assets/images/Category Cards/Hot Drinks.png',
    'drinks_cold': 'assets/images/Category Cards/Cold Drinks.png',
    'drinks_dairy': 'assets/images/Category Cards/Milk & Yogurt.png',
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
  });

  final CategoryModel category;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final imagePath = _categoryCardImagePath(category.key);
    const cardRadius = AppSpacing.radiusLg;
    const edgePad = AppSpacing.sm;

    return Material(
      color: theme.bgMid,
      elevation: 0,
      shadowColor: theme.textMain.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    child: imagePath != null
                        ? Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _e, _s) =>
                                _FallbackIcon(category: category),
                          )
                        : _FallbackIcon(category: category),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                        height: 1.12,
                      ),
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
        child: Icon(category.icon, size: 36, color: color),
      ),
    );
  }
}
