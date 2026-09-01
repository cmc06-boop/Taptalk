import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

  static const String _userSecurityCollectionName = 'user_security';

  Future<String> _sessionFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('device_session_fingerprint');
    if (id != null && id.isNotEmpty) return id;
    final generated = const Uuid().v4();
    await prefs.setString('device_session_fingerprint', generated);
    return generated;
  }

  Future<String> _localSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('active_session_id');
    if (sessionId != null && sessionId.isNotEmpty) return sessionId;
    final generated = const Uuid().v4();
    await prefs.setString('active_session_id', generated);
    return generated;
  }

  Future<void> _persistSessionState(String uid, String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_session_id', sessionId);
    await prefs.setString('active_session_uid', uid);
  }

  Future<void> _clearSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_id');
    await prefs.remove('active_session_uid');
  }

  Future<void> _markSessionMismatch(String uid, String localSessionId) async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection(_userSecurityCollectionName).doc(uid);
    final previous = (await ref.get()).data();
    final previousDevice = (previous?['currentDeviceId'] as String?)?.trim() ?? '';
    final previousSession = (previous?['currentSessionId'] as String?)?.trim() ?? '';

    await ref.set({
      'uid': uid,
      'currentSessionId': localSessionId,
      'currentDeviceId': await _sessionFingerprint(),
      'previousSessionId': previousSession,
      'previousDeviceId': previousDevice,
      'deviceChangeAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'lastMismatchAt': FieldValue.serverTimestamp(),
      'mismatchCount': FieldValue.increment(1),
      'fraudRisk': 'session_mismatch',
      'suspiciousLogin': true,
    }, SetOptions(merge: true));
  }

  Future<bool> validateCurrentSessionForThisDevice({String? uid}) async {
    if (!_initialized) return true;
    final firebaseAuth = auth;
    final currentUid = uid ?? firebaseAuth?.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) return true;

    final prefs = await SharedPreferences.getInstance();
    final localSessionId = prefs.getString('active_session_id');
    final deviceId = await _sessionFingerprint();
    final ref = FirebaseFirestore.instance
        .collection(_userSecurityCollectionName)
        .doc(currentUid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final serverSessionId = (data?['currentSessionId'] as String?)?.trim() ?? '';
    final serverDeviceId = (data?['currentDeviceId'] as String?)?.trim() ?? '';

    if (serverSessionId.isEmpty) {
      final newSessionId = await _localSessionId();
      await ref.set({
        'uid': currentUid,
        'currentSessionId': newSessionId,
        'currentDeviceId': deviceId,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'fraudRisk': 'none',
      }, SetOptions(merge: true));
      await _persistSessionState(currentUid, newSessionId);
      return true;
    }

    if (localSessionId == null || localSessionId.isEmpty) {
      final generated = await _localSessionId();
      await _persistSessionState(currentUid, generated);
      if (serverSessionId != generated) {
        await _markSessionMismatch(currentUid, generated);
        return false;
      }
    }

    if (serverSessionId != localSessionId) {
      await _markSessionMismatch(currentUid, localSessionId ?? await _localSessionId());
      return false;
    }

    if (serverDeviceId.isNotEmpty && serverDeviceId != deviceId) {
      await ref.set({
        'uid': currentUid,
        'currentDeviceId': deviceId,
        'lastDeviceMismatchAt': FieldValue.serverTimestamp(),
        'fraudRisk': 'device_change',
      }, SetOptions(merge: true));
      return false;
    }

    await ref.set({
      'uid': currentUid,
      'currentSessionId': serverSessionId,
      'currentDeviceId': deviceId,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'fraudRisk': 'none',
    }, SetOptions(merge: true));

    return true;
  }

  Future<void> registerActiveSessionForCurrentUser() async {
    if (!_initialized) return;
    final uid = auth?.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final sessionId = const Uuid().v4();
    final deviceId = await _sessionFingerprint();
    final ref = FirebaseFirestore.instance
        .collection(_userSecurityCollectionName)
        .doc(uid);

    final previous = (await ref.get()).data();
    await ref.set({
      'uid': uid,
      'currentSessionId': sessionId,
      'currentDeviceId': deviceId,
      'previousSessionId': (previous?['currentSessionId'] as String?)?.trim() ?? '',
      'previousDeviceId': (previous?['currentDeviceId'] as String?)?.trim() ?? '',
      'lastSeenAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'fraudRisk': 'none',
    }, SetOptions(merge: true));

    await _persistSessionState(uid, sessionId);
  }

  Future<void> _tryRegisterActiveSession() async {
    try {
      await registerActiveSessionForCurrentUser()
          .timeout(const Duration(seconds: 8));
    } catch (e, st) {
      debugPrint('Session register after auth failed: $e\n$st');
    }
  }

  Future<void> invalidateCurrentUserSession({String? reason}) async {
    if (!_initialized) return;
    final uid = auth?.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection(_userSecurityCollectionName)
        .doc(uid);
    await ref.set({
      'uid': uid,
      'currentSessionId': '',
      'currentDeviceId': '',
      'lastSeenAt': FieldValue.serverTimestamp(),
      'revokedAt': FieldValue.serverTimestamp(),
      'revokedReason': reason ?? 'manual',
      'fraudRisk': reason == null ? 'none' : 'forced_revoke',
    }, SetOptions(merge: true));
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
    final uid = await _withAuthTimeout<String?>(() async {
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
    if (uid != null && uid.isNotEmpty) {
      await _tryRegisterActiveSession();
    }
    return uid;
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
