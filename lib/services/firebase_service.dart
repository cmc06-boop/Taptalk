import 'dart:async';
import 'dart:io' show Platform;
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
  bool _appCheckSkipLogged = false;
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

  bool get hasActiveAuthSession {
    final uid = currentUid;
    return uid != null && uid.isNotEmpty;
  }

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
  ///
  /// On Windows, Auth restores asynchronously and auth-state EventChannel
  /// callbacks may arrive off the platform thread, so we poll [currentUser]
  /// instead of relying on [authStateChanges] alone.
  Future<String?> waitForAuthUid({
    Duration? timeout,
  }) async {
    if (!_initialized) return null;
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;

    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final effectiveTimeout = timeout ??
        (isWindows ? const Duration(seconds: 20) : const Duration(seconds: 8));

    if (isWindows) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    final immediate = firebaseAuth.currentUser;
    if (immediate != null) return immediate.uid;

    final deadline = DateTime.now().add(effectiveTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final user = firebaseAuth.currentUser;
      if (user != null) return user.uid;

      if (!isWindows) {
        try {
          return await firebaseAuth
              .authStateChanges()
              .where((candidate) => candidate != null)
              .map((candidate) => candidate!.uid)
              .first
              .timeout(const Duration(milliseconds: 600));
        } catch (_) {
          // Fall through to polling below.
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    return firebaseAuth.currentUser?.uid;
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

    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final windowsDebugToken = !kIsWeb
        ? Platform.environment['APP_CHECK_DEBUG_TOKEN']?.trim()
        : null;

    // Debug builds: unregistered App Check tokens block Firestore writes
    // (PERMISSION_DENIED) even when Firebase Auth is valid.
    if (kDebugMode) {
      final hasWindowsToken =
          isWindows &&
          windowsDebugToken != null &&
          windowsDebugToken.isNotEmpty;
      if (!hasWindowsToken) {
        if (!_appCheckSkipLogged) {
          _appCheckSkipLogged = true;
          debugPrint(
            'Skipping Firebase App Check in debug mode. '
            'Set APP_CHECK_DEBUG_TOKEN on Windows if you need App Check locally.',
          );
        }
        return;
      }
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
        providerWindows: WindowsDebugProvider(
          debugToken: windowsDebugToken != null && windowsDebugToken.isNotEmpty
              ? windowsDebugToken
              : null,
        ),
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

  /// True when Firebase Auth says the persisted user no longer exists.
  /// Network and timeout errors return false so offline sessions stay signed in.
  Future<bool> currentUserWasDeleted() async {
    if (!_initialized) return false;
    final firebaseAuth = auth;
    final user = firebaseAuth?.currentUser;
    if (firebaseAuth == null || user == null) return false;
    try {
      await user.reload();
      return firebaseAuth.currentUser == null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'user-disabled':
        case 'user-token-expired':
        case 'invalid-user-token':
          return true;
        default:
          return false;
      }
    } catch (e, st) {
      debugPrint('Firebase currentUser reload failed: $e\n$st');
      return false;
    }
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
