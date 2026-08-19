import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/category_model.dart';
import 'category_icon.dart';

class CategoryGridCard extends StatefulWidget {
  const CategoryGridCard({
    super.key,
    required this.category,
    required this.label,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final CategoryModel category;
  final String label;
  final TapTalkThemeToken theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<CategoryGridCard> createState() => _CategoryGridCardState();
}

class _CategoryGridCardState extends State<CategoryGridCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scale = _pressed ? 0.97 : (_hovering ? 1.02 : 1.0);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: scale,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.bgAccent.withValues(alpha: 0.14),
          highlightColor: theme.bgAccent.withValues(alpha: 0.08),
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovering = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: widget.selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.bgMid.withValues(alpha: 0.45),
                        theme.bgLight.withValues(alpha: 0.95),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF9FBFC)],
                    ),
              border: Border.all(
                color: widget.selected
                    ? theme.bgAccent.withValues(alpha: 0.9)
                    : const Color(0xFFE9EEF2),
                width: widget.selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.selected
                      ? theme.bgAccent.withValues(alpha: 0.22)
                      : (_hovering
                          ? theme.bgAccent.withValues(alpha: 0.12)
                          : const Color(0x11000000)),
                  blurRadius: widget.selected ? 14 : (_hovering ? 10 : 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: widget.category.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: CategoryIcon(
                      category: widget.category,
                      size: 26,
                      color: widget.selected
                          ? theme.bgAccent
                          : widget.category.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: GoogleFonts.poppins(
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12,
                    color: widget.selected ? theme.textMain : Colors.black87,
                  ),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
