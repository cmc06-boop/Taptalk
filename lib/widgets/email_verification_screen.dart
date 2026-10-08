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

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;
  bool _verified = false;
  bool _sent = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    CaregiverSecurityService.instance.listenForRecoveryEmailLinks(_onLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _send(showSent: false);
    });
  }

  @override
  void dispose() {
    CaregiverSecurityService.instance.stopListeningForRecoveryEmailLinks();
    super.dispose();
  }

  Future<void> _onLink(String link) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    final verified = await context
        .read<AppState>()
        .applyParentEmailVerificationLink(link);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (verified) {
        _verified = true;
        _message = null;
      }
    });
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
      primaryLabel: AppStrings.iVerifiedMyEmail(lang),
      onPrimary: _confirm,
      secondaryLabel: _sent
          ? AppStrings.resendVerificationEmail(lang)
          : AppStrings.sendVerificationEmail(lang),
      onSecondary: _send,
      footerLabel: AppStrings.logout(lang),
      onFooter: () => app.logout(),
    );
  }
}
