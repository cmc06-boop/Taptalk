import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_shell.dart';

enum _ForgotStep { enterEmail, checkEmail }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  _ForgotStep _step = _ForgotStep.enterEmail;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final lang = context.read<AppState>().language;
    final email = _email.text.trim();
    if (!AuthValidation.isValidEmail(email)) {
      setState(() => _error = AppStrings.invalidEmail(lang));
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    final outcome =
        await context.read<AppState>().beginPasswordReset(email);
    if (!mounted) return;

    if (outcome.error != null) {
      setState(() {
        _busy = false;
        _error = outcome.error;
      });
      return;
    }

    setState(() {
      _busy = false;
      _step = _ForgotStep.checkEmail;
    });
  }

  String _subtitle(AppLanguage lang) {
    switch (_step) {
      case _ForgotStep.enterEmail:
        return AppStrings.forgotPasswordHint(lang);
      case _ForgotStep.checkEmail:
        return AppStrings.passwordResetEmailSent(lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;

    return TapTalkShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final compactHeight = constraints.maxHeight < 760;
          final headerHeight = isWide ? 180.0 : (compactHeight ? 150.0 : 190.0);
          final contentHorizontal = isWide ? 36.0 : 24.0;
          final contentTop = compactHeight ? 16.0 : 22.0;
          final sectionGap = compactHeight ? 12.0 : 16.0;
          final isCheckEmail = _step == _ForgotStep.checkEmail;

          return Column(
            children: [
              Container(
                width: double.infinity,
                height: headerHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3ECF8E), Color(0xFFB3E6CC)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'TapTalk',
                  style: GoogleFonts.poppins(
                    fontSize: compactHeight ? 34 : 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                    shadows: const [
                      Shadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, isWide ? -34 : -50),
                  child: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(52),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        contentHorizontal,
                        contentTop,
                        contentHorizontal,
                        compactHeight ? 14 : 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (_step == _ForgotStep.checkEmail) {
                                        setState(() {
                                          _step = _ForgotStep.enterEmail;
                                          _error = null;
                                        });
                                      } else {
                                        app.setRoute(AppRoute.login);
                                      }
                                    },
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: const Color(0xFF2F5E48),
                            ),
                          ),
                          if (isCheckEmail) ...[
                            const SizedBox(height: AppSpacing.md),
                            Center(
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8F7EE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 30,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: sectionGap),
                          Text(
                            AppStrings.forgotPasswordTitle(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: compactHeight ? 22 : 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5BB88A),
                            ),
                          ),
                          SizedBox(height: compactHeight ? 8 : 10),
                          Text(
                            _subtitle(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: isCheckEmail
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF5A6B63),
                              height: 1.45,
                              fontWeight:
                                  isCheckEmail ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFC62828)),
                            ),
                          ],
                          if (_step == _ForgotStep.enterEmail) ...[
                            SizedBox(height: sectionGap),
                            _field(
                              AppStrings.email(lang),
                              _email,
                              keyboard: TextInputType.emailAddress,
                            ),
                          ],
                          const Spacer(),
                          if (_step == _ForgotStep.enterEmail)
                            FilledButton(
                              onPressed: _busy ? null : _submitEmail,
                              style: _primaryButtonStyle(compactHeight),
                              child: _buttonChild(
                                busy: _busy,
                                label: AppStrings.sendResetLink(lang),
                              ),
                            ),
                          if (isCheckEmail)
                            FilledButton(
                              onPressed: () => app.setRoute(AppRoute.login),
                              style: _primaryButtonStyle(compactHeight),
                              child: Text(
                                AppStrings.backToLogin(lang),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          SizedBox(height: compactHeight ? 10 : 14),
                          if (_step != _ForgotStep.checkEmail)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => app.setRoute(AppRoute.login),
                              child: Text(
                                AppStrings.backToLogin(lang),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF5BB88A),
                                ),
                              ),
                            ),
                          SizedBox(height: compactHeight ? 4 : 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ButtonStyle _primaryButtonStyle(bool compactHeight) {
    return FilledButton.styleFrom(
      backgroundColor: Colors.black,
      padding: EdgeInsets.symmetric(vertical: compactHeight ? 14 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buttonChild({required bool busy, required String label}) {
    if (busy) {
      return const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return Text(
      label,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFEFF8F3),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCECE4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCECE4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: const Color(0xFF5BB88A).withValues(alpha: 0.65),
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
