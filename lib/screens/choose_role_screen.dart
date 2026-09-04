import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_shell.dart';

class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  static const _titleColor = Color(0xFF1E3A2C);
  static const _subColor = Color(0xFF4F6C5D);
  static const _accent = Color(0xFF5BB88A);

  String _role = 'learner';
  bool _busy = false;
  String? _error;

  Future<void> _continue(AppState app) async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await app.completePendingGoogleSignUp(_role);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Future<void> _goBack(AppState app) async {
    if (_busy) return;
    await app.goBackFromGoogleRole();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final email = app.pendingGoogleEmail ?? '';

    return TapTalkShell(
      backgroundColor: Color.alphaBlend(
        const Color(0x22FFFFFF),
        app.theme.bgLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md + MediaQuery.paddingOf(context).top,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _busy ? null : () => _goBack(app),
                  icon: const Icon(Icons.arrow_back_rounded, color: _titleColor),
                ),
                Expanded(
                  child: Text(
                    AppStrings.chooseRoleTitle(lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AppStrings.chooseRoleSub(lang),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: _subColor,
              ),
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                email,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFFC62828),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _roleCard(
                  role: 'learner',
                  icon: Icons.back_hand_outlined,
                  title: AppStrings.learner(lang),
                  subtitle: AppStrings.chooseRoleLearnerSub(lang),
                ),
                const SizedBox(height: AppSpacing.sm),
                _roleCard(
                  role: 'parent',
                  icon: Icons.family_restroom_outlined,
                  title: AppStrings.parent(lang),
                  subtitle: AppStrings.chooseRoleParentSub(lang),
                ),
                const SizedBox(height: AppSpacing.sm),
                _roleCard(
                  role: 'teacher',
                  icon: Icons.school_outlined,
                  title: AppStrings.teacher(lang),
                  subtitle: AppStrings.chooseRoleTeacherSub(lang),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : () => _continue(app),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppStrings.continueLabel(lang)
                            .replaceAll('→', '')
                            .trimRight(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            child: Text(
              AppStrings.chooseRoleFooter(lang),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _subColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _role == role;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(16),
        splashColor: _accent.withValues(alpha: 0.12),
        highlightColor: _accent.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? _accent.withValues(alpha: 0.78)
                  : const Color(0xFFDCE7E1),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEAF8F1)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? _accent.withValues(alpha: 0.55)
                        : const Color(0xFFE5E5E5),
                  ),
                ),
                child: Icon(
                  icon,
                  color: selected ? _accent : const Color(0xFF6B7C74),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.35,
                        color: _subColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? _accent : const Color(0xFFD0D8D4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
