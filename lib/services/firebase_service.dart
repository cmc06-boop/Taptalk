import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/firebase_password_reset_result.dart';
import '../firebase_options.dart';
import 'caregiver_security_service.dart';

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
    Duration? timeout,
  }) async {
    final limit = timeout ?? _authTimeout;
    try {
      return await action().timeout(limit);
    } on TimeoutException {
      debugPrint('Firebase ${label ?? "auth"} timed out after $limit.');
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

  // Password authentication never replaces caregiver device authority.
  // The server-backed parent gate validates that separate relationship.
  Future<bool> validateCurrentSessionForThisDevice({String? uid}) async =>
      hasActiveAuthSession && (uid == null || uid == currentUid);

  Future<void> registerActiveSessionForCurrentUser() async {}

  Future<void> _tryRegisterActiveSession() async {}

  Future<void> _clearSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_id');
    await prefs.remove('active_session_uid');
  }

  Future<void> invalidateCurrentUserSession({String? reason}) async {
    await CaregiverSecurityService.instance.endSession();
    await _clearSessionState();
  }

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

    const appCheckDebugToken = String.fromEnvironment(
      'TAPTALK_APP_CHECK_DEBUG_TOKEN',
    );

    // Mobile debug providers generate a token that the developer registers
    // in Firebase App Check. Never skip them: security callables require it.
    // Windows requires an explicitly configured debug token.
    if (kDebugMode &&
        isWindows &&
        (windowsDebugToken == null || windowsDebugToken.isEmpty) &&
        appCheckDebugToken.isEmpty) {
      if (!_appCheckSkipLogged) {
        _appCheckSkipLogged = true;
        debugPrint(
          'Skipping Windows Firebase App Check: set APP_CHECK_DEBUG_TOKEN.',
        );
      }
      return;
    }

    final androidDebug = appCheckDebugToken.isNotEmpty
        ? AndroidDebugProvider(debugToken: appCheckDebugToken)
        : (kDebugMode ? const AndroidDebugProvider() : null);
    final appleDebug = appCheckDebugToken.isNotEmpty
        ? AppleDebugProvider(debugToken: appCheckDebugToken)
        : (kDebugMode ? const AppleDebugProvider() : null);

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid:
            androidDebug ?? const AndroidPlayIntegrityProvider(),
        providerApple: appleDebug ?? const AppleAppAttestProvider(),
        providerWindows: WindowsDebugProvider(
          debugToken: windowsDebugToken != null && windowsDebugToken.isNotEmpty
              ? windowsDebugToken
              : appCheckDebugToken.isNotEmpty
              ? appCheckDebugToken
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
    final uid = await _withAuthTimeout<String?>(() async {
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
    if (uid != null && uid.isNotEmpty) {
      await _tryRegisterActiveSession();
    }
    return uid;
  }

  Future<String?> createAccount({
    required String email,
    required String password,
  }) async {
    if (!_initialized) return null;
    _clearAuthError();
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;
    final normalizedEmail = email.trim().toLowerCase();
    var uid = await _withAuthTimeout<String?>(() async {
      try {
        final credential = await firebaseAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
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
    }, label: 'create-account', timeout: const Duration(seconds: 25));

    if (uid == null || uid.isEmpty) {
      uid = await _recoverUidAfterCreate(
        firebaseAuth: firebaseAuth,
        email: normalizedEmail,
        password: password,
      );
    }

    if (uid != null && uid.isNotEmpty) {
      _clearAuthError();
      await _tryRegisterActiveSession();
    }
    return uid;
  }

  /// createUser can succeed in Firebase after a client timeout, leaving the
  /// new Auth user in Console while this app still thinks sign-up failed.
  Future<String?> _recoverUidAfterCreate({
    required FirebaseAuth firebaseAuth,
    required String email,
    required String password,
  }) async {
    String? matchingUid() {
      final user = firebaseAuth.currentUser;
      final userEmail = user?.email?.trim().toLowerCase();
      if (user != null && userEmail == email) return user.uid;
      return null;
    }

    final immediate = matchingUid();
    if (immediate != null) return immediate;

    final createError = lastAuthErrorCode;
    if (createError == 'weak-password' ||
        createError == 'invalid-email' ||
        createError == 'operation-not-allowed') {
      return null;
    }

    if (createError != 'email-already-in-use') {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final polled = matchingUid();
        if (polled != null) return polled;
      }
    }

    if (createError != null &&
        createError != 'unknown' &&
        createError != 'email-already-in-use' &&
        createError != 'network-request-failed') {
      return matchingUid();
    }

    final signedIn = await signIn(email: email, password: password);
    if (signedIn != null && signedIn.isNotEmpty) {
      _clearAuthError();
      return signedIn;
    }

    if (createError == 'email-already-in-use') {
      _setAuthError('email-already-in-use');
    }
    return matchingUid();
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
    try {
      await CaregiverSecurityService.instance.endSession();
      await auth?.signOut();
    } finally {
      await _clearSessionState();
    }
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
          password: temporaryPassword(),
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

  String temporaryPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ── Phone Auth ─────────────────────────────────────────────────────────────

  /// True only on Android and iOS — Firebase Phone Auth is not supported on
  /// Windows or web.
  static bool get isPhoneAuthSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get isGoogleAuthSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<String?> signInWithGoogle() async {
    if (!_initialized) return null;
    _clearAuthError();
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;

    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final account = await googleSignIn.authenticate();

      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      final result = await firebaseAuth.signInWithCredential(credential);
      return result.user?.uid;
    } on FirebaseAuthException catch (e) {
      _setAuthError(e.code);
      debugPrint('Google sign-in failed: ${e.code} — ${e.message}');
      return null;
    } on StateError catch (e) {
      _setAuthError('google-config-missing');
      debugPrint('Google sign-in config error: $e');
      return null;
    } catch (e, st) {
      _setAuthError('unknown');
      debugPrint('Google sign-in error: $e\n$st');
      return null;
    }
  }

  /// Triggers Firebase SMS OTP for [phoneNumber] (E.164 format, e.g. +639XXXXXXXXX).
  ///
  /// Calls [onCodeSent] with the verificationId when the SMS is dispatched.
  /// Calls [onAutoVerified] if the device auto-reads the SMS (Android only).
  /// Calls [onError] with a human-readable error code on failure.
  void verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String uid) onAutoVerified,
    required void Function(String code) onError,
    int? resendToken,
  }) {
    final firebaseAuth = auth;
    if (firebaseAuth == null) {
      onError('unavailable');
      return;
    }
    firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified on Android (SMS auto-read).
        try {
          final result = await firebaseAuth.signInWithCredential(credential);
          final uid = result.user?.uid;
          if (uid != null) onAutoVerified(uid);
        } catch (e) {
          debugPrint('Phone auto-verify sign-in failed: $e');
          onError('auto-verify-failed');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('Phone verification failed: ${e.code} — ${e.message}');
        onError(e.code);
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (_) {
        // Timeout — user must enter code manually, nothing to do here.
      },
    );
  }

  /// Signs in with the SMS [smsCode] using the [verificationId] from [verifyPhoneNumber].
  /// Returns the Firebase UID on success, or null on failure (error code set in [lastAuthErrorCode]).
  Future<String?> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!_initialized) return null;
    _clearAuthError();
    final firebaseAuth = auth;
    if (firebaseAuth == null) return null;
    return _withAuthTimeout<String?>(() async {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        final result = await firebaseAuth.signInWithCredential(credential);
        return result.user?.uid;
      } on FirebaseAuthException catch (e) {
        _setAuthError(e.code);
        debugPrint('Phone OTP sign-in failed: ${e.code} — ${e.message}');
        return null;
      } catch (e, st) {
        _setAuthError('unknown');
        debugPrint('Phone OTP sign-in error: $e\n$st');
        return null;
      }
    }, label: 'phone-otp-sign-in');
  }
}
