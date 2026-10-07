import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
  Future<String>? _secretFuture;
  Future<void> _tokenApplication = Future<void>.value();
  int _authGeneration = 0;
  StreamSubscription<User?>? _authSubscription;
  String? _observedUid;

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
      if (user?.uid != _observedUid) {
        _observedUid = user?.uid;
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
        if (_authGeneration != generation ||
            FirebaseAuth.instance.currentUser?.uid != user.uid) {
          throw StateError('The signed-in account changed.');
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
      await application;
    }
    return data;
  }

  Future<void> endSession() async {
    // Prevent an earlier status response from signing back in after logout.
    _authGeneration++;
    await _tokenApplication.catchError((Object _) {});
    try {
      await call('logout');
    } catch (_) {
      // Local Auth sign-out must still work offline. No device credential is
      // removed here; a normal logout is distinct from device revocation.
    }
  }
}
