import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A random installation credential, never a phone name or an Auth password.
/// Only the server can bind its hash to a caregiver and issue a session claim.
class CaregiverSecurityService {
  CaregiverSecurityService._();
  static final instance = CaregiverSecurityService._();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  static const _emailLinks = MethodChannel('com.taptalk/email_links');
  static const _pendingRecoveryEmailKey = 'caregiver_recovery_email';
  static const recoveryContinueUrl =
      'https://taptalk-2d809.firebaseapp.com/caregiver-recovery';

  Future<String>? _secretFuture;
  Future<void> _tokenApplication = Future<void>.value();
  Future<void> get sessionReady => _tokenApplication;
  int _authGeneration = 0;
  int _sessionHold = 0;
  Timer? _authNullTimer;

  /// Email and password sign-in must finish before a trusted-session token
  /// replaces the account. A token sign-in also emits a brief signed-out event.
  void holdSessionChanges() {
    _sessionHold++;
    _authGeneration++;
  }

  void releaseSessionChanges() {
    if (_sessionHold > 0) _sessionHold--;
  }

  StreamSubscription<User?>? _authSubscription;
  String? _observedUid;
  void Function(String link)? _onEmailLink;

  Future<String> _secret() => _secretFuture ??= _loadSecret().catchError((
    Object error,
    StackTrace stack,
  ) {
    // A temporarily unavailable secure store must not poison all retries.
    _secretFuture = null;
    Error.throwWithStackTrace(error, stack);
  });

  void _watchAccount() {
    if (_authSubscription != null) return;
    _observedUid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _authNullTimer?.cancel();
      if (user == null) {
        final previous = _observedUid;
        _authNullTimer = Timer(const Duration(milliseconds: 900), () {
          final current = FirebaseAuth.instance.currentUser?.uid;
          if (current == previous) return;
          _observedUid = current;
          _authGeneration++;
        });
        return;
      }
      if (user.uid != _observedUid) {
        _observedUid = user.uid;
        _authGeneration++;
      }
    });
  }

  Set<String> get recoveryProviders {
    if (Firebase.apps.isEmpty) return const {};
    return FirebaseAuth.instance.currentUser?.providerData
            .map((provider) => provider.providerId)
            .toSet() ??
        const {};
  }

  /// Refreshes the account proof without discarding the replacement request.
  /// Firebase rejects a Google credential for a different signed-in account.
  Future<void> reauthenticate({String? password, bool google = false}) async {
    _watchAccount();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in again before recovery.');
    final generation = _authGeneration;
    late final AuthCredential credential;
    if (google) {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final account = await signIn.authenticate();
      credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
    } else {
      if (user.email == null || password == null || password.isEmpty) {
        throw StateError('Enter your account password.');
      }
      credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
    }
    if (_authGeneration != generation ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('The signed-in account changed.');
    }
    await user.reauthenticateWithCredential(credential);
    if (_authGeneration != generation ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('The signed-in account changed.');
    }
    await user.getIdToken(true);
  }

  ActionCodeSettings recoveryActionCodeSettings(String requestId) =>
      ActionCodeSettings(
        url: Uri.parse(
          recoveryContinueUrl,
        ).replace(queryParameters: {'requestId': requestId}).toString(),
        handleCodeInApp: true,
        androidPackageName: 'com.example.flutter_application_1',
        androidInstallApp: false,
        iOSBundleId: 'com.example.flutterApplication1',
      );

  Future<void> sendRecoveryEmailLink(String email, String requestId) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) throw StateError('Recovery email is unavailable.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRecoveryEmailKey, trimmed);
    await FirebaseAuth.instance.sendSignInLinkToEmail(
      email: trimmed,
      actionCodeSettings: recoveryActionCodeSettings(requestId),
    );
  }

  Future<String?> takePendingEmailLink() async {
    try {
      final link = await _emailLinks.invokeMethod<String>('getInitialLink');
      if (link != null && link.isNotEmpty) return link;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    return null;
  }

  void listenForRecoveryEmailLinks(void Function(String link) onLink) {
    _onEmailLink = onLink;
    _emailLinks.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        final link = call.arguments as String;
        if (link.isNotEmpty) _onEmailLink?.call(link);
      }
    });
    unawaited(
      takePendingEmailLink().then((link) {
        if (link != null) _onEmailLink?.call(link);
      }),
    );
  }

  void stopListeningForRecoveryEmailLinks() {
    _onEmailLink = null;
    _emailLinks.setMethodCallHandler(null);
  }

  /// Hosting app links wrap the sign-in link in a `link` query parameter.
  static String unwrapEmailLink(String link) {
    var current = link.trim();
    for (var depth = 0; depth < 3; depth++) {
      final inner = Uri.tryParse(current)?.queryParameters['link'];
      if (inner == null || inner.isEmpty) break;
      current = inner;
    }
    return current;
  }

  static bool isRecoveryEmailLink(String link) {
    final uri = Uri.tryParse(unwrapEmailLink(link));
    return uri?.queryParameters['mode'] == 'signIn' &&
        (uri?.queryParameters['oobCode']?.isNotEmpty ?? false);
  }

  /// One-time code from the email; the server redeems it as proof of email
  /// ownership because ID tokens cannot tell an email-link sign-in apart.
  static String? recoveryOobCode(String rawLink) {
    final link = unwrapEmailLink(rawLink);
    if (!FirebaseAuth.instance.isSignInWithEmailLink(link)) return null;
    final code = Uri.tryParse(link)?.queryParameters['oobCode'];
    return code == null || code.isEmpty ? null : code;
  }

  Future<bool> completeRecoveryEmailLink(String rawLink) async {
    final link = unwrapEmailLink(rawLink);
    if (!FirebaseAuth.instance.isSignInWithEmailLink(link)) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in again before recovery.');
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_pendingRecoveryEmailKey) ?? user.email ?? '';
    if (email.isEmpty) throw StateError('Recovery email is unavailable.');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credentialWithLink(email: email, emailLink: link),
    );
    await user.getIdToken(true);
    return true;
  }

  /// Same value the server stores for this phone; parent link queries filter
  /// on it because rules only expose learners bound to the trusted phone.
  Future<String> deviceHash() async =>
      sha256.convert(utf8.encode(await _secret())).toString();

  Future<String> _loadSecret() async {
    final prefs = await SharedPreferences.getInstance();
    // Keychain values may survive uninstall on Apple platforms. The app-data
    // marker makes a reinstall require verification even in that case.
    final installed = prefs.getBool('caregiver_credential_installed') == true;
    final stored = installed
        ? await _storage.read(key: 'caregiver_device_secret')
        : null;
    if (stored != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(stored)) {
      return stored;
    }
    final random = Random.secure();
    final secret = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: 'caregiver_device_secret', value: secret);
    await prefs.setBool('caregiver_credential_installed', true);
    return secret;
  }

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> values = const {},
    bool waitForToken = true,
  ]) async {
    _watchAccount();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in online to verify this device.');
    final generation = _authGeneration;
    final secret = await _secret();
    if (_authGeneration != generation ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('The signed-in account changed.');
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable(
          'caregiverSecurity',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        )
        .call<Map<String, dynamic>>({
          ...values,
          'action': action,
          'deviceSecret': secret,
        });
    if (_authGeneration != generation ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('The signed-in account changed.');
    }
    final data = Map<String, dynamic>.from(result.data);
    if (data['token'] is String) {
      final application = _tokenApplication.catchError((Object _) {}).then((
        _,
      ) async {
        if (_sessionHold > 0 ||
            _authGeneration != generation ||
            FirebaseAuth.instance.currentUser?.uid != user.uid) {
          return;
        }
        await FirebaseAuth.instance.signInWithCustomToken(
          data['token'] as String,
        );
        if (_authGeneration != generation ||
            FirebaseAuth.instance.currentUser?.uid != user.uid) {
          throw StateError('The signed-in account changed.');
        }
      });
      _tokenApplication = application;
      if (waitForToken) await application;
    }
    return data;
  }

  Future<void> endSession() async {
    // Prevent an earlier status response from signing back in after logout.
    _authGeneration++;
    _authNullTimer?.cancel();
    unawaited(_tokenApplication.catchError((Object _) {}));
    unawaited(() async {
      try {
        await call('logout');
      } catch (_) {
        // Local sign-out still finishes. This only clears the server session.
      }
    }());
  }
}
