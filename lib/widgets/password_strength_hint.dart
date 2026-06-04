import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';

class PasswordStrengthHint extends StatelessWidget {
  const PasswordStrengthHint({
    super.key,
    required this.password,
    required this.lang,
    this.showRequirementsWhenEmpty = true,
  });

  final String password;
  final AppLanguage lang;
  final bool showRequirementsWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final strength = AuthValidation.evaluatePasswordStrength(password);

    if (strength == PasswordStrength.empty && !showRequirementsWhenEmpty) {
      return const SizedBox.shrink();
    }

    final String text;
    final Color color;

    switch (strength) {
      case PasswordStrength.empty:
        text = AppStrings.passwordRequirements(lang);
        color = const Color(0xFF5A6B63);
      case PasswordStrength.weak:
        text = AppStrings.weakPassword(lang);
        color = const Color(0xFFC62828);
      case PasswordStrength.strong:
        text = AppStrings.strongPassword(lang);
        color = const Color(0xFF2E7D32);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.35,
        ),
      ),
    );
  }
}
