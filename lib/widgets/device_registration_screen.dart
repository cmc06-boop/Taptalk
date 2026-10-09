import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../services/caregiver_security_service.dart';
import 'security_step_layout.dart';

/// Blocks a parent account on any phone that is not its trusted phone.
/// Tapping the emailed link opens TapTalk here; one more tap makes this the
/// trusted phone. The same steps recover access after a lost phone.
class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen>
    with WidgetsBindingObserver {
  final _password = TextEditingController();
  Timer? _approvalTimer;
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const _resendCooldown = 60;
  bool _busy = false;
  bool _checkingApproval = false;
  bool _sent = false;
  bool _needsReauth = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _password.addListener(_refresh);
    _approvalTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkApproval(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApproval());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _approvalTimer?.cancel();
    _resendTimer?.cancel();
    _password.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkApproval();
  }

  Future<void> _send({bool google = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await context.read<AppState>().sendDeviceRegistrationLink(
      password: _needsReauth ? _password.text : null,
      google: google,
    );
    if (!mounted) return;
    final firstReauthPrompt = result.needsReauth && !_needsReauth;
    setState(() {
      _busy = false;
      _needsReauth = result.needsReauth;
      _sent = result.error == null || _sent;
      if (result.error == null) _password.clear();
      _message = firstReauthPrompt ? null : result.error;
      _messageIsError = _message != null;
    });
    if (result.error == null) {
      _startResendTimer();
      unawaited(_checkApproval());
    }
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

  Future<void> _checkApproval() async {
    if (!mounted || _busy || _checkingApproval) return;
    _checkingApproval = true;
    final result = await context
        .read<AppState>()
        .checkDeviceRegistrationApproval();
    _checkingApproval = false;
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _sent = false;
        _message = result.error;
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final logout = AppStrings.logout(lang);

    if (app.deviceRegistrationDone) {
      return SecurityStepLayout(
        icon: Icons.verified_user_outlined,
        title: AppStrings.phoneRegisteredTitle(lang),
        subtitle: AppStrings.phoneRegisteredBody(lang),
        primaryLabel: AppStrings.continueToTapTalk(lang),
        onPrimary: app.finishDeviceRegistration,
      );
    }

    if (app.deviceCheckPending) {
      return SecurityStepLayout(
        icon: Icons.phonelink_lock_outlined,
        title: AppStrings.checkingThisPhone(lang),
        subtitle: AppStrings.checkingThisPhoneBody(lang),
        busy: !app.deviceCheckUnavailable,
        message: app.deviceCheckUnavailable
            ? AppStrings.deviceCheckUnavailable(lang)
            : null,
        messageIsError: true,
        primaryLabel: AppStrings.tryAgain(lang),
        onPrimary: app.retryDeviceCheck,
        footerLabel: logout,
        onFooter: () => app.logout(),
      );
    }

    final providers = CaregiverSecurityService.instance.recoveryProviders;
    final hasPassword = providers.contains('password');
    final hasGoogle = providers.contains('google.com');

    if (_needsReauth) {
      final googleOnly = !hasPassword && hasGoogle;
      return SecurityStepLayout(
        icon: Icons.lock_outline_rounded,
        title: AppStrings.confirmItsYou(lang),
        subtitle: AppStrings.confirmItsYouBody(lang),
        busy: _busy,
        message: _message,
        messageIsError: _messageIsError,
        primaryLabel: googleOnly
            ? AppStrings.confirmWithGoogle(lang)
            : AppStrings.continueLabel(lang).replaceAll('→', '').trim(),
        onPrimary: googleOnly
            ? () => _send(google: true)
            : (_password.text.isEmpty ? null : _send),
        secondaryLabel: !googleOnly && hasGoogle
            ? AppStrings.confirmWithGoogle(lang)
            : null,
        onSecondary: () => _send(google: true),
        footerLabel: logout,
        onFooter: () => app.logout(),
        children: [
          if (hasPassword)
            SecurityStepField(
              controller: _password,
              label: AppStrings.confirmAccountPassword(lang),
              obscure: true,
            ),
        ],
      );
    }

    if (_sent) {
      return SecurityStepLayout(
        icon: Icons.forward_to_inbox_outlined,
        title: AppStrings.checkYourEmail(lang),
        subtitle: AppStrings.deviceLinkSent(
          lang,
          app.deviceRegistrationEmail ?? '',
        ),
        busy: _busy,
        message: _message,
        messageIsError: _messageIsError,
        primaryLabel: AppStrings.waitingForConfirmation(lang),
        onPrimary: null,
        secondaryLabel: _resendSecondsLeft > 0
            ? AppStrings.resendIn(_resendSecondsLeft, lang)
            : AppStrings.resendDeviceLink(lang),
        onSecondary: _resendSecondsLeft > 0 ? null : _send,
        footerLabel: logout,
        onFooter: () => app.logout(),
      );
    }

    return SecurityStepLayout(
      icon: Icons.phonelink_lock_outlined,
      title: AppStrings.verifyThisDevice(lang),
      subtitle: AppStrings.verifyThisDeviceBody(lang),
      busy: _busy,
      message: _message,
      messageIsError: _messageIsError,
      primaryLabel: AppStrings.sendDeviceLink(lang),
      onPrimary: _send,
      footerLabel: logout,
      onFooter: () => app.logout(),
    );
  }
}
