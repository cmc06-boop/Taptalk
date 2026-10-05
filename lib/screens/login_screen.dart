import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';
import '../providers/app_state.dart';
import '../widgets/offline_notice_banner.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _appliedLoginPrefill = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedLoginPrefill) return;
    final prefill = context.read<AppState>().loginPrefillEmail;
    if (prefill != null && prefill.isNotEmpty) {
      _email.text = prefill;
      context.read<AppState>().clearLoginPrefill();
    }
    _appliedLoginPrefill = true;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = context.read<AppState>().language;
    final missing =
        _email.text.trim().isEmpty || _password.text.isEmpty;
    if (missing) {
      setState(() => _error = AppStrings.fillAllFields(lang));
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _error = null);
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final err = await context.read<AppState>().login(
            _email.text,
            _password.text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
      });
    } catch (e) {
      debugPrint('Login screen error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppStrings.loginFailedTryAgain(
          context.read<AppState>().language,
        );
      });
    }
  }

  Future<void> _continueWithGoogle(AppState app) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await app.signInWithGoogle();
    if (!mounted) return;
    if (err == AppState.googleNeedsRole) {
      setState(() => _busy = false);
      await app.setRoute(AppRoute.chooseRole);
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    }
  }

  Widget _googleIcon() {
    return Image.asset(
      'assets/images/Logo/google.png',
      width: 20,
      height: 20,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboard,
    TextInputAction? textInputAction,
    bool autocorrect = true,
    ValueChanged<String>? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF5A6B63),
        ),
        filled: true,
        fillColor: const Color(0xFFEFF8F3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscure ? 'Unhide $label' : 'Hide $label',
                    icon: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF5A6B63),
                            size: 19,
                          ),
                          Text(
                            obscure ? 'Unhide' : 'Hide',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5A6B63),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onPressed: onToggleObscure,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC62828)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.6),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom >
            MediaQuery.paddingOf(context).bottom
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQuery.paddingOf(context).bottom;

    return TapTalkShell(
      coloredHeader: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final compactHeight = constraints.maxHeight < 760;
          final headerHeight = isWide ? 268.0 : (compactHeight ? 232.0 : 286.0);
          final sheetOverlap = isWide ? 34.0 : 50.0;
          final logoSize = compactHeight ? 70.0 : 86.0;
          final contentHorizontal = isWide ? 36.0 : 24.0;
          final contentTop = compactHeight ? 16.0 : 22.0;
          final sectionGap = compactHeight ? 12.0 : 16.0;
          final fieldGap = compactHeight ? 10.0 : 14.0;

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
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: sheetOverlap + 6),
                  child: TapTalkWordmark(
                    height: compactHeight ? 152 : 178,
                    maxWidth: compactHeight ? 440 : 480,
                  ),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, -sheetOverlap),
                  child: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(52),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        contentHorizontal,
                        contentTop,
                        contentHorizontal,
                        (compactHeight ? 14 : 18) + bottomInset,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: TapTalkLogo(size: logoSize)),
                            SizedBox(height: compactHeight ? 10 : 12),
                            Semantics(
                              header: true,
                              child: Text(
                                AppStrings.loginTitle(lang),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: compactHeight ? 22 : 24,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF5BB88A),
                                ),
                              ),
                            ),
                            OfflineNoticeText(
                              lang: lang,
                              noticeContext: OfflineNoticeContext.login,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFC62828)),
                              ),
                            ],
                            SizedBox(height: sectionGap),
                            _field(
                              AppStrings.email(lang),
                              _email,
                              keyboard: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                if (!AuthValidation.isValidEmail(value)) {
                                  return AppStrings.invalidEmail(lang);
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: fieldGap),
                            _field(
                              AppStrings.password(lang),
                              _password,
                              obscure: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            SizedBox(height: compactHeight ? 6 : 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => app.setRoute(AppRoute.forgotPassword),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(48, 48),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ),
                                child: Text(
                                  AppStrings.forgotPassword(lang),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF5BB88A),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: sectionGap),
                            Semantics(
                              button: true,
                              enabled: !_busy,
                              label: 'Submit ${AppStrings.loginTitle(lang)}',
                              excludeSemantics: true,
                              onTap: _busy ? null : _submit,
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(
                                    vertical: compactHeight ? 14 : 16,
                                  ),
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
                                        AppStrings.loginTitle(lang),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: compactHeight ? 10 : 14),
                            SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => app.setRoute(AppRoute.register),
                                child: Center(
                                  child: Text.rich(
                                    textAlign: TextAlign.center,
                                    TextSpan(
                                      text: '${AppStrings.noAccount(lang)} ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF2F5E48),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: AppStrings.signUp(lang),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF5BB88A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 2),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _continueWithGoogle(app),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF2F5E48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: const Size(48, 48),
                                      tapTargetSize: MaterialTapTargetSize.padded,
                                      backgroundColor: Colors.transparent,
                                      surfaceTintColor: Colors.transparent,
                                      overlayColor: const Color(0xFF5BB88A).withValues(alpha: 0.08),
                                    ),
                                    icon: _googleIcon(),
                                    label: Text(
                                      'Continue with Google',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2F5E48),
                                      ),
                                    ),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
