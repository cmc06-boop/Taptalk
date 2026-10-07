import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/caregiver_security_service.dart';
import 'link_child_dialog.dart';

typedef CaregiverSecurityCall =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> values,
    );

/// Wrap route content so the pop entry belongs to the actual main route, rather
/// than to MaterialApp.builder, which is above the main Navigator.
class CaregiverSecurityRoute extends StatelessWidget {
  const CaregiverSecurityRoute({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CaregiverBackScope>();
    if (scope == null) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(scope.onBack());
      },
      child: child,
    );
  }
}

class _CaregiverBackScope extends InheritedWidget {
  const _CaregiverBackScope({required this.onBack, required super.child});
  final Future<void> Function() onBack;
  @override
  bool updateShouldNotify(_CaregiverBackScope oldWidget) =>
      onBack != oldWidget.onBack;
}

/// Keeps the main navigator mounted and hides its cached content until a fresh
/// server response verifies caregiver access. Callbacks also allow native-free
/// widget tests of the same protection and replacement flow.
class CaregiverSecurityGate extends StatefulWidget {
  const CaregiverSecurityGate({
    super.key,
    required this.child,
    this.call,
    this.applyLinks,
    this.onTrusted,
    this.onRevoked,
    this.onLogout,
    this.onMainBack,
    this.reauthenticate,
    this.recoveryProviders,
    this.pollInterval = const Duration(seconds: 15),
  });

  final Widget child;
  final CaregiverSecurityCall? call;
  final Future<void> Function(List<dynamic> links)? applyLinks;
  final Future<void> Function()? onTrusted;
  final Future<void> Function()? onRevoked;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onMainBack;
  final Future<void> Function(String password, bool google)? reauthenticate;
  final Set<String>? recoveryProviders;
  final Duration pollInterval;

  @override
  State<CaregiverSecurityGate> createState() => _CaregiverSecurityGateState();
}

class _CaregiverSecurityGateState extends State<CaregiverSecurityGate>
    with WidgetsBindingObserver {
  final _security = CaregiverSecurityService.instance;
  final _securityNavigator = GlobalKey<NavigatorState>();
  final _code = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _presentedRequests = <String>{};
  List<String> _pendingRequests = [];
  bool _recoveryVerified = false;
  bool _showRecovery = false;
  String? _transferLearnerId;
  Timer? _timer;
  String _state = 'checking';
  String? _message;
  String? _requestId;
  bool _busy = false;
  bool _manage = false;
  bool _wasTrusted = false;
  bool _foreground = true;
  bool _checkPending = false;
  bool _loggingOut = false;
  bool _autoReplacementRequested = false;
  int _lifecycleGeneration = 0;

  AppState? get _app => context.read<AppState?>();
  bool get _mainVisible => _foreground && _state == 'trusted' && !_manage;

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> values = const {},
  ]) => widget.call?.call(action, values) ?? _security.call(action, values);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
    _timer = Timer.periodic(widget.pollInterval, (_) {
      if (_foreground) unawaited(_check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _foreground = state == AppLifecycleState.resumed;
    _lifecycleGeneration++;
    if (!_foreground) {
      setState(() => _state = 'checking');
    } else {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (!mounted || !_foreground || _loggingOut) return;
    if (_busy) {
      _checkPending = true;
      return;
    }
    final generation = _lifecycleGeneration;
    setState(() => _busy = true);
    try {
      final result = await _call('status');
      if (!mounted || !_foreground || generation != _lifecycleGeneration) {
        return;
      }
      final next = result['state'] as String;
      if (_wasTrusted && next == 'verificationRequired') {
        setState(() => _state = 'verificationRequired');
        _loggingOut = true;
        await (widget.onRevoked?.call() ?? _app?.logout());
        return;
      }
      final newlyTrusted = next == 'trusted' && !_wasTrusted;
      if (next == 'trusted') {
        final links = result['links'] as List? ?? [];
        await (widget.applyLinks?.call(links) ??
            _app?.applyVerifiedCaregiverLinks(links));
        if (!mounted || !_foreground || generation != _lifecycleGeneration) {
          return;
        }
      }
      final requests = (result['requests'] as List? ?? [])
          .map((request) => request['id'] as String)
          .toList();
      setState(() {
        _state = next;
        _wasTrusted |= next == 'trusted';
        _pendingRequests = requests;
        if (requests.any((request) => !_presentedRequests.contains(request))) {
          _manage = true;
          _presentedRequests.addAll(requests);
        }
        if (next == 'trusted') _message = null;
      });
      if (next == 'verificationRequired' &&
          _requestId == null &&
          !_autoReplacementRequested) {
        _autoReplacementRequested = true;
        final replacement = await _call('requestReplacement');
        if (!mounted || !_foreground || generation != _lifecycleGeneration) return;
        setState(() {
          _requestId = replacement['requestId'] as String;
          _message = _actionMessage('requestReplacement');
        });
      }
      if (newlyTrusted) {
        unawaited(
          widget.onTrusted?.call() ??
              _app?.refreshLinkedChildren(cloudSyncInBackground: false) ??
              Future<void>.value(),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted && generation == _lifecycleGeneration) {
        setState(() {
          _state = 'unavailable';
          _message = error.code == 'unauthenticated'
              ? 'Sign in to your account again to verify this phone.'
              : 'Unable to check protected access. Connect to the internet and try again.';
        });
      }
    } catch (_) {
      if (mounted && generation == _lifecycleGeneration) {
        setState(() {
          _state = 'unavailable';
          _message =
              'Unable to check protected access. Connect to the internet and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_checkPending && _foreground && !_loggingOut) {
          _checkPending = false;
          unawaited(_check());
        }
      }
    }
  }

  String _actionMessage(String action) => switch (action) {
    'requestReplacement' =>
      'Replacement request created. It expires in 15 minutes. Your old phone is still trusted.',
    'requestTransfer' =>
      'Transfer request created. Give this code to the current caregiver.',
    'sendRecovery' =>
      'An 8-digit code was sent to your registered recovery email. It expires in 5 minutes.',
    'verifyRecovery' =>
      'Recovery email verified. Confirm below to replace your trusted phone.',
    'confirmReplacement' => 'Trusted phone replaced.',
    'approveReplacement' => 'New phone approved. This phone has been revoked.',
    'transfer' =>
      'Caregiver transfer complete. Your previous access has been revoked.',
    _ => 'Request complete.',
  };

  Future<void> _action(
    String action, [
    Map<String, dynamic> values = const {},
  ]) async {
    if (_busy || _loggingOut) return;
    setState(() => _busy = true);
    try {
      final result = await _call(action, values);
      if (!mounted) return;
      setState(() {
        _requestId = result['requestId'] as String? ?? _requestId;
        if (action == 'requestReplacement') {
          _recoveryVerified = false;
          _showRecovery = false;
          _otp.clear();
        }
        if (action == 'verifyRecovery') _recoveryVerified = true;
        _message = _actionMessage(action);
        if ([
          'confirmReplacement',
          'approveReplacement',
          'transfer',
        ].contains(action)) {
          // Do not reveal cached content while confirmation is being checked.
          _state = 'checking';
        }
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error.code) {
            'resource-exhausted' =>
              'Too many attempts. Please try again later.',
            'unauthenticated' =>
              'Verify your account again below, then request a new email code.',
            'failed-precondition' =>
              'Verify your account email before continuing.',
            _ =>
              action == 'verifyRecovery'
                  ? 'The code is incorrect, expired, or no longer available. Request a new code and try again.'
                  : 'Request unavailable. Check the request code or create a new request.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not complete the request. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if ([
          'confirmReplacement',
          'approveReplacement',
          'transfer',
        ].contains(action) ||
        _checkPending) {
      _checkPending = false;
      await _check();
    }
  }

  Future<void> _verifyAccountAndSendCode(bool google) async {
    if (_busy || _requestId == null) return;
    setState(() => _busy = true);
    var verified = false;
    try {
      await (widget.reauthenticate?.call(_password.text, google) ??
          _security.reauthenticate(password: _password.text, google: google));
      verified = true;
      _password.clear();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _message = error.code == 'too-many-requests'
              ? 'Too many verification attempts. Please try again later.'
              : 'Account verification failed. Use the credentials for this signed-in parent account.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Account verification was not completed. Try again with this parent account.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (verified && mounted) {
      await _action('sendRecovery', {'requestId': _requestId});
    }
    if (_checkPending && mounted) {
      _checkPending = false;
      await _check();
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() {
      _loggingOut = true;
      _state = 'checking';
    });
    await (widget.onLogout?.call() ?? _app?.logout());
  }

  Future<void> _back() async {
    if (_mainVisible) {
      await (widget.onMainBack?.call() ?? _app?.handleSystemBack());
      return;
    }
    final navigator = _securityNavigator.currentState;
    if (navigator != null && navigator.canPop()) {
      await navigator.maybePop();
    } else if (_state == 'trusted' && _manage && !_busy) {
      setState(() => _manage = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _otp.dispose();
    _password.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CaregiverBackScope(
      onBack: _back,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: !_mainVisible,
            child: ExcludeFocus(
              excluding: !_mainVisible,
              child: TickerMode(enabled: _mainVisible, child: widget.child),
            ),
          ),
          if (_mainVisible)
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: Semantics(
                  button: true,
                  label: 'Trusted device',
                  child: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => setState(() => _manage = true),
                      icon: const Icon(Icons.security),
                    ),
                  ),
                ),
              ),
            )
          else
            // This opaque navigator shields both visible and cached routes.
            // Keeping its page identity stable preserves an open QR scanner.
            HeroControllerScope.none(
              child: Navigator(
                key: _securityNavigator,
                pages: [
                  MaterialPage<void>(
                    key: const ValueKey('caregiver-security-panel'),
                    child: Builder(builder: _panel),
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext scanContext) {
    final providers = widget.recoveryProviders ?? _security.recoveryProviders;
    final children = _app?.linkedChildren ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted device'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user_outlined, size: 56),
              const SizedBox(height: 20),
              Text(
                _state == 'trusted'
                    ? 'This phone is trusted.'
                    : _state == 'setup'
                    ? 'Link your learner to get started.'
                    : _state == 'checking'
                    ? 'Checking protected access...'
                    : 'Protected learner information is locked.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_state == 'setup') ...[
                const Text(
                  'First verify your account email, then scan the learner QR. The verified email will be used for lost-phone recovery.',
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            await FirebaseAuth.instance.currentUser
                                ?.sendEmailVerification();
                            if (mounted) {
                              setState(
                                () => _message =
                                    'Verification email sent. Open its link, then try linking again.',
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => _message =
                                    'Unable to send verification email. Try again later.',
                              );
                            }
                          }
                        },
                  child: const Text('Send email verification'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _action('requestTransfer'),
                  child: const Text('Receive a caregiver transfer'),
                ),
                if (_requestId != null)
                  SelectableText(
                    'Give this transfer request to the current caregiver:\n$_requestId',
                  ),
                const Text(
                  'Scan the learner QR to establish your caregiver link and authorize this phone.',
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await LinkChildDialog.show(scanContext);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                          _checkPending = false;
                          await _check();
                        },
                  child: const Text('Scan learner QR'),
                ),
              ] else if (_state == 'trusted') ...[
                for (final requestId in _pendingRequests)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'A new phone requests access. Compare this code with your new phone before approving.',
                          ),
                          SelectableText(requestId),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _action('approveReplacement', {
                                    'requestId': requestId,
                                  }),
                            child: const Text(
                              'Approve new device and revoke this phone',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Text(
                  'To replace this phone, enter the request code shown on your new phone. Approve only a request you started yourself.',
                ),
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Replacement or transfer request code',
                  ),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action('approveReplacement', {
                          'requestId': _code.text.trim(),
                        }),
                  child: const Text('Approve my new phone'),
                ),
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Caregiver transfer: select a learner and enter the new caregiver’s transfer request. This removes your learner access and ends your trusted session.',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _transferLearnerId,
                    decoration: const InputDecoration(
                      labelText: 'Learner to transfer',
                    ),
                    items: children
                        .map(
                          (child) => DropdownMenuItem(
                            value: child.learnerId.toString(),
                            child: Text(child.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _transferLearnerId = value,
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final localId = int.tryParse(
                              _transferLearnerId ?? '',
                            );
                            if (localId == null) {
                              setState(
                                () => _message =
                                    'Select the learner you want to transfer.',
                              );
                              return;
                            }
                            final uid = await _app?.linkedLearnerFirebaseUid(
                              localId,
                            );
                            if (uid != null && mounted) {
                              await _action('transfer', {
                                'learnerUid': uid,
                                'requestId': _code.text.trim(),
                              });
                            }
                          },
                    child: const Text('Confirm transfer and revoke my access'),
                  ),
                ],
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _manage = false),
                  child: const Text('Back to TapTalk'),
                ),
              ] else if (_state == 'verificationRequired') ...[
                const Text(
                  'Your previous trusted phone remains active. Request approval there, or verify your account and recovery email if it is lost or unavailable.',
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _action('requestReplacement'),
                  child: const Text('Create replacement request'),
                ),
                if (_requestId != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(_requestId!),
                  const Text(
                    'The old trusted phone will show your approval request. Once approved, this phone will unlock automatically.',
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showRecovery = true),
                    child: const Text("I can't access my old device"),
                  ),
                  if (_showRecovery) ...[
                    const Text(
                      'Verify ownership of this parent account. Then enter the code sent to the recovery email registered with your trusted phone.',
                    ),
                    if (providers.contains('password')) ...[
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Account password',
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _verifyAccountAndSendCode(false),
                        child: const Text(
                          'Verify password and send email code',
                        ),
                      ),
                    ],
                    if (providers.contains('google.com'))
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _verifyAccountAndSendCode(true),
                        child: const Text(
                          'Verify Google account and send email code',
                        ),
                      ),
                    if (!providers.contains('password') &&
                        !providers.contains('google.com'))
                      const Text(
                        'Sign in again with your parent account email/password or Google account to use recovery.',
                      ),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: '8-digit email code',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _action('verifyRecovery', {
                              'requestId': _requestId,
                              'otp': _otp.text.trim(),
                            }),
                      child: const Text('Verify recovery code'),
                    ),
                    if (_recoveryVerified) ...[
                      const Text(
                        'Replace your trusted device? This will remove access from your previous device.',
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _action('confirmReplacement', {
                                'requestId': _requestId,
                              }),
                        child: const Text(
                          'Confirm replacement and revoke old phone',
                        ),
                      ),
                    ],
                  ],
                ],
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_message!),
                ),
              if (_busy || _state == 'checking')
                const Center(child: CircularProgressIndicator()),
              TextButton(
                onPressed: _busy || _loggingOut ? null : _check,
                child: const Text('Check access again'),
              ),
              TextButton(
                onPressed: _loggingOut ? null : _logout,
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
