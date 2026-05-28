import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/category_model.dart';
import '../providers/app_state.dart';

/// Section title row matching the prototype (icon + "Feelings Phrases").
class PhraseSectionHeader extends StatelessWidget {
  const PhraseSectionHeader({
    super.key,
    required this.category,
    required this.categoryLabel,
  });

  final CategoryModel? category;
  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        AppStrings.phrasesLabel(categoryLabel, lang),
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: theme.textMain,
          height: 1.2,
        ),
      ),
    );
  }
}
