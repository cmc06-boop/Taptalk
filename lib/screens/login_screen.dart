import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await context.read<AppState>().login(
          _email.text,
          _password.text,
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
          final compactHeight = constraints.maxHeight < 760;
          final headerHeight = isWide ? 180.0 : (compactHeight ? 150.0 : 190.0);
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
                          Center(child: TapTalkLogo(size: logoSize)),
                          SizedBox(height: sectionGap),
                          Text(
                            AppStrings.loginTitle(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: compactHeight ? 22 : 24,
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
                          _field(AppStrings.email(lang), _email,
                              keyboard: TextInputType.emailAddress),
                          SizedBox(height: fieldGap),
                          _field(
                            AppStrings.password(lang),
                            _password,
                            obscure: _obscurePassword,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(vertical: compactHeight ? 14 : 16),
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
                                    style:
                                        GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                          ),
                          SizedBox(height: compactHeight ? 10 : 14),
                          Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              text: '${AppStrings.noAccount(lang)} ',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF2F5E48),
                              ),
                              children: [
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () =>
                                        app.setRoute(AppRoute.register),
                                    child: Text(
                                      AppStrings.signUp(lang),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF5BB88A),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
