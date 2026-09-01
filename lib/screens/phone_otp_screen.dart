import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../services/firebase_service.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  static const _otpLength = 6;
  static const _resendCooldown = 60;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  String? _error;
  bool _busy = false;
  int _resendSecondsLeft = _resendCooldown;
  Timer? _resendTimer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSecondsLeft > 0) {
          _resendSecondsLeft--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextEmpty = digits.length < _otpLength ? digits.length : _otpLength - 1;
      _focusNodes[nextEmpty].requestFocus();
      if (_otpCode.length == _otpLength) _submit();
      return;
    }
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otpCode.length == _otpLength) _submit();
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _submit() async {
    final code = _otpCode;
    if (code.length < _otpLength) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    final app = context.read<AppState>();
    final lang = app.language;
    final verificationId = app.pendingPhoneVerificationId;
    final phoneNumber = app.pendingPhoneNumber ?? '';
    final isRegister = app.pendingPhoneIsRegister;
    if (verificationId == null) {
      setState(() => _error = AppStrings.invalidOtp(lang));
      return;
    }
    setState(() { _error = null; _busy = true; });
    try {
      final uid = await FirebaseService.instance.signInWithPhoneOtp(
        verificationId: verificationId,
        smsCode: code,
      );
      if (!mounted) return;
      if (uid == null) {
        final errCode = FirebaseService.instance.lastAuthErrorCode;
        setState(() { _busy = false; _error = _otpErrorMessage(errCode, lang); });
        return;
      }
      String? err;
      if (isRegister) {
        err = await app.registerWithPhone(
          uid: uid,
          phoneNumber: phoneNumber,
          firstName: app.pendingPhoneFirstName ?? '',
          lastName: app.pendingPhoneLastName ?? '',
          role: app.pendingPhoneRole ?? 'learner',
        );
      } else {
        err = await app.loginWithPhone(uid, phoneNumber);
      }
      if (!mounted) return;
      if (err != null) setState(() { _busy = false; _error = err; });
    } catch (e) {
      debugPrint('PhoneOtpScreen submit error: $e');
      if (!mounted) return;
      setState(() { _busy = false; _error = AppStrings.invalidOtp(lang); });
    }
  }

  Future<void> _resend() async {
    final app = context.read<AppState>();
    final lang = app.language;
    final phone = app.pendingPhoneNumber;
    if (phone == null) return;
    setState(() { _resending = true; _error = null; });
    await FirebaseService.instance.initialize();
    FirebaseService.instance.verifyPhoneNumber(
      phoneNumber: phone,
      resendToken: app.pendingPhoneResendToken,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        app.updatePhoneResendToken(verificationId, resendToken);
        setState(() => _resending = false);
        _startResendTimer();
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      },
      onAutoVerified: (uid) async {
        if (!mounted) return;
        setState(() => _busy = true);
        final err = app.pendingPhoneIsRegister
            ? await app.registerWithPhone(
                uid: uid, phoneNumber: phone,
                firstName: app.pendingPhoneFirstName ?? '',
                lastName: app.pendingPhoneLastName ?? '',
                role: app.pendingPhoneRole ?? 'learner')
            : await app.loginWithPhone(uid, phone);
        if (!mounted) return;
        if (err != null) setState(() { _busy = false; _error = err; });
      },
      onError: (code) {
        if (!mounted) return;
        setState(() { _resending = false; _error = _otpErrorMessage(code, lang); });
      },
    );
  }

  String _otpErrorMessage(String? code, AppLanguage lang) {
    switch (code) {
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return AppStrings.invalidOtp(lang);
      case 'session-expired':
        return lang == AppLanguage.filipino
            ? 'Expired na ang OTP session. Mag-resend.'
            : 'OTP session expired. Please resend.';
      case 'too-many-requests':
        return lang == AppLanguage.filipino
            ? 'Masyadong maraming pagsubok. Subukang muli mamaya.'
            : 'Too many attempts. Please try again later.';
      default:
        return AppStrings.invalidOtp(lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final phone = app.pendingPhoneNumber ?? '';
    final maskedPhone = _maskPhone(phone);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom >
            MediaQuery.paddingOf(context).bottom
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQuery.paddingOf(context).bottom;

    return TapTalkShell(
      coloredHeader: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final compactHeight = constraints.maxHeight < 680;
          final headerHeight = isWide ? 240.0 : (compactHeight ? 200.0 : 240.0);
          final sheetOverlap = isWide ? 34.0 : 42.0;
          final contentHorizontal = isWide ? 40.0 : 28.0;

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
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: sheetOverlap + 6),
                        child: TapTalkWordmark(
                          height: compactHeight ? 140 : 162,
                          maxWidth: compactHeight ? 400 : 440,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, -sheetOverlap),
                  child: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(52)),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        contentHorizontal, compactHeight ? 16 : 24,
                        contentHorizontal, (compactHeight ? 14 : 20) + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: TapTalkLogo(size: compactHeight ? 56 : 70)),
                          SizedBox(height: compactHeight ? 10 : 14),
                          Text(
                            AppStrings.verifyOtp(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: compactHeight ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5BB88A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.otpSentTo(maskedPhone, lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5A6B63)),
                          ),
                          SizedBox(height: compactHeight ? 20 : 28),

                          // ── 6-digit OTP boxes ──────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_otpLength, (i) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: SizedBox(
                                  width: 44,
                                  height: 54,
                                  child: KeyboardListener(
                                    focusNode: FocusNode(skipTraversal: true),
                                    onKeyEvent: (event) => _onKeyEvent(i, event),
                                    child: TextFormField(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(_otpLength),
                                      ],
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2F5E48),
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFEFF8F3),
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFDCECE4)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFDCECE4)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF5BB88A), width: 2),
                                        ),
                                      ),
                                      onChanged: (v) => _onDigitChanged(i, v),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFC62828))),
                          ],

                          SizedBox(height: compactHeight ? 18 : 24),

                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _busy
                                ? const SizedBox(height: 22, width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(AppStrings.verifyOtp(lang),
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),

                          const SizedBox(height: 14),

                          Center(
                            child: _resending
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5BB88A)))
                                : _resendSecondsLeft > 0
                                    ? Text(AppStrings.resendIn(_resendSecondsLeft, lang),
                                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9E9E9E)))
                                    : TextButton(
                                        onPressed: _resend,
                                        child: Text(AppStrings.resendOtp(lang),
                                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                                            color: const Color(0xFF5BB88A)))),
                          ),

                          const SizedBox(height: 6),

                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    final app = context.read<AppState>();
                                    app.clearPendingPhoneAuth();
                                    await app.popRoute();
                                  },
                            child: Text(
                              '← Back',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF5A6B63),
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

  String _maskPhone(String phone) {
    if (phone.length < 8) return phone;
    final last4 = phone.substring(phone.length - 4);
    final prefix = phone.length > 6 ? phone.substring(0, 3) : phone.substring(0, 2);
    return '$prefix *** *** $last4';
  }
}
