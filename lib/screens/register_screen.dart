import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';
import '../providers/app_state.dart';
import '../widgets/offline_notice_banner.dart';
import '../widgets/password_strength_hint.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _role = 'learner';
  String? _error;
  bool _busy = false;
  bool _attemptedSubmit = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool? _emailInUse;
  Timer? _emailCheckDebounce;
  int _emailCheckGeneration = 0;
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _email.addListener(_scheduleEmailAvailabilityCheck);
  }

  @override
  void dispose() {
    _emailCheckDebounce?.cancel();
    _email.removeListener(_scheduleEmailAvailabilityCheck);
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _scheduleEmailAvailabilityCheck() {
    _emailCheckDebounce?.cancel();
    _emailCheckDebounce = Timer(
      const Duration(milliseconds: 350),
      _checkEmailAvailability,
    );
  }

  Future<void> _checkEmailAvailability() async {
    final rawEmail = _email.text;
    final normalized = AuthValidation.normalizeEmail(rawEmail);
    if (!AuthValidation.isValidEmail(normalized)) {
      if (_emailInUse != null && mounted) {
        setState(() => _emailInUse = null);
      }
      return;
    }

    final app = context.read<AppState>();
    final generation = ++_emailCheckGeneration;
    final inUse = await app.isEmailAlreadyInUse(normalized);
    if (!mounted || generation != _emailCheckGeneration) return;
    if (AuthValidation.normalizeEmail(_email.text) != normalized) return;

    setState(() => _emailInUse = inUse);
    _emailFieldKey.currentState?.validate();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    final lang = app.language;

    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = null);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = AppStrings.passwordsDoNotMatch(lang));
      return;
    }
    if (!AuthValidation.isStrongPassword(_password.text)) {
      setState(() => _error = AppStrings.passwordTooShort(lang));
      return;
    }

    final emailTaken = await app.isEmailAlreadyInUse(_email.text);
    if (!mounted) return;
    if (emailTaken) {
      setState(() => _emailInUse = true);
      _emailFieldKey.currentState?.validate();
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final err = await app.register(
            fullName:
                '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
            firstName: _firstName.text.trim(),
            email: _email.text,
            password: _password.text,
            role: _role,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
        if (err == AppStrings.emailInUse(lang)) {
          _emailInUse = true;
        }
      });
      if (err == AppStrings.emailInUse(lang)) {
        _emailFieldKey.currentState?.validate();
      }
    } catch (e) {
      debugPrint('Register screen error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppStrings.signUpFailedTryAgain(lang);
      });
    }
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
          final compactHeight = constraints.maxHeight < 820;
          final headerHeight = isWide ? 176.0 : (compactHeight ? 130.0 : 170.0);
          final logoSize = compactHeight ? 64.0 : 80.0;
          final contentHorizontal = isWide ? 36.0 : 24.0;
          final contentTop = compactHeight ? 12.0 : 18.0;
          final sectionGap = compactHeight ? 10.0 : 14.0;
          final fieldGap = compactHeight ? 8.0 : 12.0;
          final roleHeight = compactHeight ? 60.0 : 68.0;

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: headerHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF3ECF8E), Color(0xFFB3E6CC)],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                    Text(
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
                    Positioned(
                      left: 4,
                      top: 0,
                      child: IconButton(
                        onPressed: () => app.setRoute(AppRoute.welcome),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, isWide ? -34 : -42),
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
                        (compactHeight ? 12 : 18) + bottomInset,
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _attemptedSubmit
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: TapTalkLogo(size: logoSize)),
                            SizedBox(height: sectionGap),
                            Text(
                              AppStrings.signUp(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: compactHeight ? 21 : 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5BB88A),
                              ),
                            ),
                            OfflineNoticeText(
                              lang: lang,
                              noticeContext: OfflineNoticeContext.signUp,
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _field(
                                    AppStrings.firstName(lang),
                                    _firstName,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return AppStrings.fillAllFields(lang);
                                      }
                                      if (!AuthValidation.isValidFullName(
                                          value)) {
                                        return AppStrings.invalidFullName(lang);
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _field(
                                    AppStrings.lastName(lang),
                                    _lastName,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return AppStrings.fillAllFields(lang);
                                      }
                                      if (!AuthValidation.isValidFullName(
                                          value)) {
                                        return AppStrings.invalidFullName(lang);
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: fieldGap),
                            _field(
                              AppStrings.email(lang),
                              _email,
                              fieldKey: _emailFieldKey,
                              keyboard: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return AppStrings.fillAllFields(lang);
                                }
                                if (!AuthValidation.isValidEmail(value)) {
                                  return AppStrings.invalidEmail(lang);
                                }
                                if (_emailInUse == true) {
                                  return AppStrings.emailInUse(lang);
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: fieldGap),
                            _field(
                              AppStrings.password(lang),
                              _password,
                              liveBorderStrength: _attemptedSubmit ||
                                      _password.text.isNotEmpty
                                  ? AuthValidation.evaluatePasswordStrength(
                                      _password.text,
                                    )
                                  : PasswordStrength.empty,
                              obscure: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              validator: (value) {
                                if (!_attemptedSubmit &&
                                    (value == null || value.isEmpty)) {
                                  return null;
                                }
                                if (value == null || value.isEmpty) {
                                  return AppStrings.fillAllFields(lang);
                                }
                                if (!AuthValidation.isStrongPassword(value)) {
                                  return AppStrings.passwordTooShort(lang);
                                }
                                return null;
                              },
                            ),
                            PasswordStrengthHint(
                              password: _password.text,
                              lang: lang,
                            ),
                            SizedBox(height: fieldGap),
                            _field(
                              AppStrings.confirmPassword(lang),
                              _confirmPassword,
                              obscure: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              onToggleObscure: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                              validator: (value) {
                                if (!_attemptedSubmit &&
                                    (value == null || value.isEmpty)) {
                                  return null;
                                }
                                if (value == null || value.isEmpty) {
                                  return AppStrings.fillAllFields(lang);
                                }
                                if (value != _password.text) {
                                  return AppStrings.passwordsDoNotMatch(lang);
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: sectionGap),
                            Text(
                              AppStrings.whatAreYou(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: compactHeight ? 12 : 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5A6B63),
                              ),
                            ),
                            SizedBox(height: compactHeight ? 6 : 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _roleOption(
                                    'learner',
                                    Icons.back_hand_outlined,
                                    AppStrings.learner(lang),
                                    height: roleHeight,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _roleOption(
                                    'parent',
                                    Icons.family_restroom_outlined,
                                    AppStrings.parent(lang),
                                    height: roleHeight,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _roleOption(
                                    'teacher',
                                    Icons.school_outlined,
                                    AppStrings.teacher(lang),
                                    height: roleHeight,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: sectionGap),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                minimumSize: Size(
                                  double.infinity,
                                  compactHeight ? 44 : 48,
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
                                      AppStrings.createAccount(lang),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            TextButton(
                              onPressed: () => app.setRoute(AppRoute.login),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text.rich(
                                textAlign: TextAlign.center,
                                TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF2F5E48),
                                  ),
                                  children: [
                                    TextSpan(text: '${AppStrings.hasAccount(lang)} '),
                                    TextSpan(
                                      text: AppStrings.loginTitle(lang),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF5BB88A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _roleOption(
    String role,
    IconData icon,
    String label, {
    required double height,
  }) {
    final selected = _role == role;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0xFF5BB88A).withValues(alpha: 0.12),
        highlightColor: const Color(0xFF5BB88A).withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5BB88A).withValues(alpha: 0.78)
                  : const Color(0xFFDCE7E1),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF5BB88A).withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEAF8F1) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF5BB88A).withValues(alpha: 0.55)
                        : const Color(0xFFE5E5E5),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? const Color(0xFF5BB88A) : const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF5BB88A) : const Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    GlobalKey<FormFieldState<String>>? fieldKey,
    PasswordStrength? liveBorderStrength,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboard,
    TextInputAction? textInputAction,
    bool autocorrect = true,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    const defaultBorderColor = Color(0xFFDCECE4);
    const weakBorderColor = Color(0xFFC62828);
    const focusBorderColor = Color(0xFF5BB88A);

    final borderColor = switch (liveBorderStrength) {
      PasswordStrength.weak => weakBorderColor,
      PasswordStrength.strong => defaultBorderColor,
      _ => defaultBorderColor,
    };
    final focusedBorderColor = liveBorderStrength == PasswordStrength.weak
        ? weakBorderColor
        : focusBorderColor.withValues(alpha: 0.65);
    final focusedBorderWidth =
        liveBorderStrength == PasswordStrength.weak ? 1.0 : 1.6;

    OutlineInputBorder outlineBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: fieldKey,
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          textInputAction: textInputAction,
          autocorrect: autocorrect,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFEFF8F3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            errorStyle: GoogleFonts.poppins(fontSize: 11),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF5A6B63),
                      size: 19,
                    ),
                    onPressed: onToggleObscure,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
            border: outlineBorder(defaultBorderColor),
            enabledBorder: outlineBorder(borderColor),
            focusedBorder: outlineBorder(
              focusedBorderColor,
              width: focusedBorderWidth,
            ),
            errorBorder: outlineBorder(weakBorderColor),
            focusedErrorBorder: outlineBorder(weakBorderColor, width: 1.6),
          ),
        ),
      ],
    );
  }
}
