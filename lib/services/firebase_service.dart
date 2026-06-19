import 'dart:async';
import 'dart:math';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/models/firebase_password_reset_result.dart';
import '../firebase_options.dart';

/// Initializes Firebase Auth used for cross-device notification delivery.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  bool _appCheckActivated = false;
  String? _lastAuthErrorCode;

  static const _authTimeout = Duration(seconds: 12);
  static const _initTimeout = Duration(seconds: 10);

  bool get isAvailable => _initialized;

  String? get lastAuthErrorCode => _lastAuthErrorCode;

  void _clearAuthError() => _lastAuthErrorCode = null;

  void _setAuthError(String? code) => _lastAuthErrorCode = code;

  Future<T?> _withAuthTimeout<T>(
    Future<T?> Function() action, {
    String? label,
  }) async {
    try {
      return await action().timeout(_authTimeout);
    } on TimeoutException {
      debugPrint('Firebase ${label ?? "auth"} timed out after $_authTimeout.');
      return null;
    }
  }

  FirebaseAuth? get auth {
    if (!_initialized || Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instanceFor(app: Firebase.app());
  }

  String? get currentUid => auth?.currentUser?.uid;

  String? get currentUserEmail => auth?.currentUser?.email;

  String? get currentUserDisplayName => auth?.currentUser?.displayName;

  Future<void> updateDisplayName(String displayName) async {
    if (!_initialized) return;
    final name = displayName.trim();
    if (name.isEmpty) return;
    final user = auth?.currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(name);
    } catch (e, st) {
      debugPrint('Firebase updateDisplayName failed: $e\n$st');
    }
  }

  /// Waits for Firebase Auth to restore a persisted session after [initialize].
  Future<String?> waitForAuthUid({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_initialized) return null;
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;
    final existing = firebaseAuth.currentUser;
    if (existing != null) return existing.uid;
    try {
      return await firebaseAuth
          .authStateChanges()
          .where((user) => user != null)
          .map((user) => user!.uid)
          .first
          .timeout(timeout);
    } catch (_) {
      return firebaseAuth.currentUser?.uid;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (Firebase.apps.isNotEmpty) {
      _initialized = true;
      await _activateAppCheck();
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_initTimeout);
      _initialized = Firebase.apps.isNotEmpty;
      if (_initialized) {
        await _activateAppCheck();
        debugPrint('Firebase initialized.');
      }
    } on TimeoutException {
      debugPrint('Firebase init timed out; app continues offline.');
    } catch (e, st) {
      debugPrint('Firebase init failed: $e\n$st');
    }
  }

  Future<void> _activateAppCheck() async {
    if (_appCheckActivated) return;
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      _appCheckActivated = true;
      debugPrint('Firebase App Check activated.');
    } catch (e, st) {
      debugPrint('Firebase App Check activation failed: $e\n$st');
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_initialized) return null;
    _clearAuthError();
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;
    return _withAuthTimeout<String?>(() async {
      try {
        final credential = await firebaseAuth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        return credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        _setAuthError(e.code);
        debugPrint('Firebase sign-in failed: ${e.code} — ${e.message}');
        return null;
      } catch (e, st) {
        _setAuthError('unknown');
        debugPrint('Firebase sign-in error: $e\n$st');
        return null;
      }
    }, label: 'sign-in');
  }

  Future<String?> createAccount({
    required String email,
    required String password,
  }) async {
    if (!_initialized) return null;
    _clearAuthError();
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;
    return _withAuthTimeout<String?>(() async {
      try {
        final credential = await firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        return credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        _setAuthError(e.code);
        debugPrint('Firebase create account failed: ${e.code} — ${e.message}');
        return null;
      } catch (e, st) {
        _setAuthError('unknown');
        debugPrint('Firebase create account error: $e\n$st');
        return null;
      }
    }, label: 'create-account');
  }

  /// Signs in existing Firebase users or creates one for legacy local accounts.
  Future<String?> signInOrCreateAccount({
    required String email,
    required String password,
  }) async {
    final existingUid = await signIn(email: email, password: password);
    if (existingUid != null) return existingUid;
    return createAccount(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await auth?.signOut();
  }

  /// Sends Firebase's password-reset email (for online accounts).
  Future<FirebasePasswordResetResult> sendPasswordResetEmail({
    required String email,
  }) async {
    if (!_initialized) {
      return FirebasePasswordResetResult.failed(errorCode: 'unavailable');
    }
    final firebaseAuth = auth;
    if (firebaseAuth == null) {
      return FirebasePasswordResetResult.failed(errorCode: 'unavailable');
    }
    final result = await _withAuthTimeout<FirebasePasswordResetResult>(() async {
      try {
        await firebaseAuth.sendPasswordResetEmail(
          email: email.trim().toLowerCase(),
        );
        return FirebasePasswordResetResult.sent();
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase reset email failed: ${e.code} — ${e.message}');
        return FirebasePasswordResetResult.failed(errorCode: e.code);
      } catch (e, st) {
        debugPrint('Firebase reset email error: $e\n$st');
        return FirebasePasswordResetResult.failed(errorCode: 'unknown');
      }
    }, label: 'password-reset-email');
    return result ?? FirebasePasswordResetResult.failed(errorCode: 'timeout');
  }

  /// Creates a Firebase Auth user for legacy local-only accounts so reset
  /// emails can be delivered. Returns the new UID, or null if one already exists.
  Future<String?> provisionAuthAccountForPasswordReset({
    required String email,
  }) async {
    if (!_initialized) return null;
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;
    return _withAuthTimeout<String?>(() async {
      try {
        final credential = await firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: _temporaryPassword(),
        );
        return credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return null;
        }
        debugPrint(
          'Firebase provision for reset failed: ${e.code} — ${e.message}',
        );
        return null;
      } catch (e, st) {
        debugPrint('Firebase provision for reset error: $e\n$st');
        return null;
      }
    }, label: 'provision-for-reset');
  }

  String _temporaryPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
