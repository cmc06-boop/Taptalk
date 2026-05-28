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
          return Column(
            children: [
              Container(
                width: double.infinity,
                height: isWide ? 200 : 220,
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
                  style: GoogleFonts.tiltWarp(fontSize: 32, color: Colors.white),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, isWide ? -48 : -72),
                  child: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(120),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xxl,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: TapTalkLogo(size: 100)),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            AppStrings.signUp(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
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
                          const SizedBox(height: AppSpacing.lg),
                          _field(AppStrings.fullName(lang), _name),
                          const SizedBox(height: AppSpacing.md),
                          _field(
                            AppStrings.email(lang),
                            _email,
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _field(
                            AppStrings.password(lang),
                            _password,
                            obscure: _obscurePassword,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _field(
                            AppStrings.confirmPassword(lang),
                            _confirmPassword,
                            obscure: _obscureConfirm,
                            onToggleObscure: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            AppStrings.whatAreYou(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5A6B63),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
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
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: () => app.setRoute(AppRoute.login),
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

  Widget _roleOption(String role, IconData icon, String label) {
    final selected = _role == role;
    return InkWell(
      onTap: () => setState(() => _role = role),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFD6F3E3) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFF5BB88A) : const Color(0xFFE0E0E0),
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: selected ? const Color(0xFF5BB88A) : const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF5BB88A) : const Color(0xFF9E9E9E),
            ),
          ),
        ],
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
            fillColor: const Color(0xFFD6F3E3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF5A6B63),
                    ),
                    onPressed: onToggleObscure,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
