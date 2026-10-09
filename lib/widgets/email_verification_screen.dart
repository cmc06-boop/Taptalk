import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../services/caregiver_security_service.dart';
import 'security_step_layout.dart';

/// One-time account check. It leaves as soon as Firebase marks the email
/// verified and does not ask again on later launches.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _verified = false;
  bool _sent = false;
  bool _polling = false;
  String? _message;
  bool _messageIsError = false;
  Timer? _poll;
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const _resendCooldown = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CaregiverSecurityService.instance.listenForRecoveryEmailLinks(_onLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _send(showSent: false);
    });
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollVerified());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _resendTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    CaregiverSecurityService.instance.stopListeningForRecoveryEmailLinks();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_pollVerified());
  }

  /// The link can be opened on another phone. This phone reloads until
  /// Firebase marks the email verified, then continues on its own.
  Future<void> _pollVerified() async {
    if (!mounted || _busy || _verified || _polling) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _polling = true;
    try {
      await user.reload();
    } catch (_) {
      _polling = false;
      return;
    }
    if (!mounted) return;
    if (FirebaseAuth.instance.currentUser?.emailVerified != true) {
      _polling = false;
      return;
    }
    _poll?.cancel();
    await context.read<AppState>().confirmParentEmailVerified();
    _polling = false;
  }

  Future<void> _onLink(String link) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    final verified = await context
        .read<AppState>()
        .applyParentEmailVerificationLink(link);
    if (!mounted) return;
    if (verified) _poll?.cancel();
    setState(() => _busy = false);
  }

  Future<void> _send({bool showSent = true}) async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final error = await app.sendParentVerificationEmail();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = error == null;
      _messageIsError = error != null;
      _message =
          error ??
          (showSent ? AppStrings.verificationEmailSent(app.language) : null);
    });
    if (error == null) _startResendTimer();
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final verified = await app.confirmParentEmailVerified();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verified = verified;
      _messageIsError = !verified;
      _message = verified ? null : AppStrings.emailNotVerifiedYet(app.language);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final isTeacher = app.user?.isTeacher == true;
    final email =
        FirebaseAuth.instance.currentUser?.email ?? app.user?.email ?? '';

    if (_verified) {
      return SecurityStepLayout(
        icon: Icons.mark_email_read_outlined,
        title: AppStrings.emailVerifiedTitle(lang),
        subtitle: AppStrings.emailVerifiedBody(lang),
        primaryLabel: AppStrings.continueToTapTalk(lang),
        onPrimary: app.finishParentEmailVerification,
      );
    }

    return SecurityStepLayout(
      icon: Icons.email_outlined,
      title: AppStrings.verifyEmailTitle(lang),
      subtitle: AppStrings.verifyEmailBody(lang, email),
      busy: _busy,
      message: _message,
      messageIsError: _messageIsError,
      showPrimary: !isTeacher,
      primaryLabel: AppStrings.iVerifiedMyEmail(lang),
      onPrimary: isTeacher ? null : _confirm,
      secondaryLabel: !_sent
          ? AppStrings.sendVerificationEmail(lang)
          : _resendSecondsLeft > 0
          ? AppStrings.resendIn(_resendSecondsLeft, lang)
          : AppStrings.resendVerificationEmail(lang),
      onSecondary: _sent && _resendSecondsLeft > 0 ? null : _send,
      footerLabel: AppStrings.logout(lang),
      onFooter: () => app.logout(),
    );
  }
}
