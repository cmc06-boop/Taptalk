import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/l10n/app_strings.dart';
import '../services/network_status.dart';

enum OfflineNoticeContext {
  login,
  signUp,
  passwordReset,
}

/// Plain offline hint shown at the bottom of auth screens.
class OfflineNoticeText extends StatefulWidget {
  const OfflineNoticeText({
    super.key,
    required this.lang,
    required this.noticeContext,
  });

  final AppLanguage lang;
  final OfflineNoticeContext noticeContext;

  @override
  State<OfflineNoticeText> createState() => _OfflineNoticeTextState();
}

class _OfflineNoticeTextState extends State<OfflineNoticeText> {
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final offline = await NetworkStatus.isOffline();
    if (!mounted) return;
    if (offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _message() {
    switch (widget.noticeContext) {
      case OfflineNoticeContext.login:
        return AppStrings.loginOfflineNotice(widget.lang);
      case OfflineNoticeContext.signUp:
        return AppStrings.signUpOfflineNotice(widget.lang);
      case OfflineNoticeContext.passwordReset:
        return AppStrings.passwordResetOfflineNotice(widget.lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _message(),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFC62828),
          height: 1.4,
        ),
      ),
    );
  }
}
