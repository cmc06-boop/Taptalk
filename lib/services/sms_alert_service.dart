import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models/sms_alert_result.dart';

class SmsAlertService {
  static const _functionsRegion = 'asia-southeast1';
  static const _projectId = 'taptalk-2d809';

  SmsAlertService({FirebaseFunctions? functions, FirebaseApp? app})
      : _app = app ?? Firebase.app(),
        _functions = functions ??
            FirebaseFunctions.instanceFor(
              app: app ?? Firebase.app(),
              region: _functionsRegion,
            );

  final FirebaseApp _app;
  final FirebaseFunctions _functions;

  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);

  Uri get _httpEndpoint => Uri.parse(
        'https://$_functionsRegion-$_projectId.cloudfunctions.net/sendSmsAlertHttp',
      );

  Map<String, Object?> _payload({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required int classId,
    required String className,
    required String alertType,
    required String title,
    required String body,
  }) {
    return <String, Object?>{
      'learnerUserId': learnerUserId,
      'learnerName': learnerName,
      'learnerFirebaseUid': learnerFirebaseUid,
      'classId': classId,
      'className': className,
      'alertType': alertType,
      'title': title,
      'body': body,
    };
  }

  SmsAlertResult _fromResponseMap(Map<String, dynamic> data) {
    final invalid = (data['invalidContacts'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return SmsAlertResult(
      attempted: (data['attempted'] as num?)?.toInt() ?? 0,
      sent: (data['sent'] as num?)?.toInt() ?? 0,
      failed: (data['failed'] as num?)?.toInt() ?? 0,
      invalidContacts: invalid,
    );
  }

  Future<SmsAlertResult> sendTeacherSmsAlert({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required int classId,
    required String className,
    required String alertType,
    required String title,
    required String body,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return const SmsAlertResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        errorMessage: 'unauthenticated',
      );
    }

    final payload = _payload(
      learnerUserId: learnerUserId,
      learnerName: learnerName,
      learnerFirebaseUid: learnerFirebaseUid,
      classId: classId,
      className: className,
      alertType: alertType,
      title: title,
      body: body,
    );

    try {
      final token = await authUser.getIdToken(true);
      if (token == null || token.isEmpty) {
        return const SmsAlertResult(
          attempted: 0,
          sent: 0,
          failed: 0,
          errorMessage: 'unauthenticated',
        );
      }

      // Prefer HTTP + Bearer token (reliable on Cloud Functions v2 / Cloud Run).
      final httpResult = await _sendViaHttp(token: token, payload: payload);
      if (httpResult.errorMessage != 'unauthenticated') {
        return httpResult;
      }

      debugPrint(
        'SMS HTTP returned unauthenticated; trying callable fallback.',
      );
      return await _sendViaCallable(payload);
    } on FirebaseFunctionsException catch (e) {
      return SmsAlertResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        errorMessage: e.message ?? e.code,
      );
    } catch (e) {
      return SmsAlertResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<SmsAlertResult> _sendViaHttp({
    required String token,
    required Map<String, Object?> payload,
  }) async {
    try {
      final response = await http
          .post(
            _httpEndpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = <String, dynamic>{'message': response.body};
      }

      if (response.statusCode == 200) {
        return _fromResponseMap(body);
      }

      final error = body['error'] as String? ??
          body['message'] as String? ??
          'HTTP ${response.statusCode}';
      return SmsAlertResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        errorMessage: error,
      );
    } catch (e) {
      return SmsAlertResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<SmsAlertResult> _sendViaCallable(
    Map<String, Object?> payload,
  ) async {
    final callable = _functions.httpsCallable(
      'sendSmsAlert',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final response = await callable.call(payload);
    final data = (response.data as Map).cast<String, dynamic>();
    return _fromResponseMap(data);
  }
}
