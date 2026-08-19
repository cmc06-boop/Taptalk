import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../data/models/category_model.dart';
import '../providers/app_state.dart';

/// Section title row for the phrase list.
/// Shows an optional back arrow (when [onBack] is provided) followed by the
/// category label — no "Phrases" suffix.
class PhraseSectionHeader extends StatelessWidget {
  const PhraseSectionHeader({
    super.key,
    required this.category,
    required this.categoryLabel,
    this.onBack,
  });

  final CategoryModel? category;
  final String categoryLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: theme.textMain,
                ),
              ),
            ),
          ],
          Expanded(
            child: Text(
              categoryLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textMain,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
