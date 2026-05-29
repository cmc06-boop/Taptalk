import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _role = 'learner';
  String? _error;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = context.read<AppState>().language;

    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      setState(() => _error = AppStrings.fillAllFields(lang));
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = AppStrings.passwordsDoNotMatch(lang));
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await context.read<AppState>().register(
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
          role: _role,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;

    return TapTalkShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final compactHeight = constraints.maxHeight < 820;
          final headerHeight = isWide ? 176.0 : (compactHeight ? 130.0 : 170.0);
          final logoSize = compactHeight ? 70.0 : 86.0;
          final contentHorizontal = isWide ? 36.0 : 24.0;
          final contentTop = compactHeight ? 10.0 : 16.0;
          final sectionGap = compactHeight ? 8.0 : 14.0;
          final fieldGap = compactHeight ? 6.0 : 10.0;
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
                    shadows: [
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
                  offset: Offset(0, isWide ? -34 : -42),
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
                        compactHeight ? 8 : 14,
                      ),
                      child: SingleChildScrollView(
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
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFC62828)),
                            ),
                          ],
                          SizedBox(height: sectionGap),
                          _field(AppStrings.fullName(lang), _name),
                          SizedBox(height: fieldGap),
                          _field(
                            AppStrings.email(lang),
                            _email,
                            keyboard: TextInputType.emailAddress,
                          ),
                          SizedBox(height: fieldGap),
                          _field(
                            AppStrings.password(lang),
                            _password,
                            obscure: _obscurePassword,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          SizedBox(height: fieldGap),
                          _field(
                            AppStrings.confirmPassword(lang),
                            _confirmPassword,
                            obscure: _obscureConfirm,
                            onToggleObscure: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
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
                          SizedBox(height: compactHeight ? 4 : 8),
                          Row(
                            children: [
                              Expanded(
                                child: _roleOption(
                                  'learner',
                                  Icons.back_hand_outlined,
                                  AppStrings.learner(lang),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _roleOption(
                                  'parent',
                                  Icons.family_restroom_outlined,
                                  AppStrings.parent(lang),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _roleOption(
                                  'teacher',
                                  Icons.school_outlined,
                                  AppStrings.teacher(lang),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compactHeight ? 8 : 12),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              minimumSize: Size(double.infinity, compactHeight ? 42 : 46),
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
                                    AppStrings.createAccount(lang),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          SizedBox(height: compactHeight ? 0 : 6),
                          TextButton(
                            onPressed: () => app.setRoute(AppRoute.login),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: RichText(
                              text: TextSpan(
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
                          SizedBox(height: compactHeight ? 0 : 2),
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

  Widget _roleOption(String role, IconData icon, String label) {
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
          height: 68,
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
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1, end: selected ? 1.03 : 1),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEAF8F1)
                          : const Color(0xFFF5F5F5),
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
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF5BB88A) : const Color(0xFF9E9E9E),
                  ),
                  child: Text(label),
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
    bool obscure = false,
    VoidCallback? onToggleObscure,
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
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFEFF8F3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF5A6B63),
                      size: 19,
                    ),
                    onPressed: onToggleObscure,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFDCECE4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFDCECE4),
              ),
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
