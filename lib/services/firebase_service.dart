import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase Auth used for cross-device notification delivery.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;

  static const _authTimeout = Duration(seconds: 12);
  static const _initTimeout = Duration(seconds: 10);

  bool get isAvailable => _initialized;

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

  FirebaseAuth get auth {
    if (!_initialized) return FirebaseAuth.instance;
    return FirebaseAuth.instanceFor(app: Firebase.app());
  }

  String? get currentUid => auth.currentUser?.uid;

  /// Waits for Firebase Auth to restore a persisted session after [initialize].
  Future<String?> waitForAuthUid({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_initialized) return null;
    final existing = auth.currentUser;
    if (existing != null) return existing.uid;
    try {
      return await auth
          .authStateChanges()
          .where((user) => user != null)
          .map((user) => user!.uid)
          .first
          .timeout(timeout);
    } catch (_) {
      return auth.currentUser?.uid;
    }
  }

  /// Ensures a valid ID token for Cloud Functions (e.g. [sendSmsAlert]).
  Future<String?> ensureCallableAuth({String? expectedUid}) async {
    if (!_initialized) return null;
    var uid = auth.currentUser?.uid ?? await waitForAuthUid();
    if (uid == null) return null;
    if (expectedUid != null &&
        expectedUid.isNotEmpty &&
        uid != expectedUid.trim()) {
      return null;
    }
    try {
      await auth.currentUser?.getIdToken(true);
      return auth.currentUser?.uid;
    } catch (e, st) {
      debugPrint('Firebase ID token refresh failed: $e\n$st');
      return null;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp().timeout(_initTimeout);
      _initialized = true;
      debugPrint('Firebase initialized.');
    } on TimeoutException {
      debugPrint('Firebase init timed out; app continues offline.');
    } catch (e, st) {
      debugPrint('Firebase init failed (add google-services.json): $e\n$st');
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_initialized) return null;
    return _withAuthTimeout<String?>(() async {
      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        return credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase sign-in failed: ${e.code} — ${e.message}');
        return null;
      } catch (e, st) {
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
    return _withAuthTimeout<String?>(() async {
      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        return credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase create account failed: ${e.code} — ${e.message}');
        return null;
      } catch (e, st) {
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
    await auth.signOut();
  }

  /// Sends Firebase's password-reset email (for online accounts).
  Future<bool> sendPasswordResetEmail({required String email}) async {
    if (!_initialized) return false;
    final result = await _withAuthTimeout<bool>(() async {
      try {
        await auth.sendPasswordResetEmail(
          email: email.trim().toLowerCase(),
        );
        return true;
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase reset email failed: ${e.code} — ${e.message}');
        return false;
      } catch (e, st) {
        debugPrint('Firebase reset email error: $e\n$st');
        return false;
      }
    }, label: 'password-reset-email');
    return result ?? false;
  }
}
