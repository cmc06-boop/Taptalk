import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/l10n/app_strings.dart';
import 'package:flutter_application_1/services/device_sms_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const smsChannel = MethodChannel('com.taptalk/direct_sms');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  late List<MethodCall> calls;
  late bool granted;
  late bool submit;
  late int permissionRequests;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    granted = true;
    submit = true;
    permissionRequests = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(permissions, (
      call,
    ) async {
      if (call.method == 'requestPermissions') {
        permissionRequests++;
        return {Permission.sms.value: granted ? 1 : 0};
      }
      return granted ? 1 : 0;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(smsChannel, (
      call,
    ) async {
      calls.add(call);
      return {'sent': submit ? 1 : 0, 'failed': submit ? 0 : 1, 'attempted': 1};
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(smsChannel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(permissions, null);
  });
  Future<dynamic> send(DeviceSmsService sms) => sms.sendAutomaticAlert(
    language: AppLanguage.english,
    phoneNumber: '+639171234567',
    message: 'Test warning',
  );

  test(
    'automatic SMS submits to Android directly without opening a composer',
    () async {
      final result = await send(DeviceSmsService());
      expect(result.sent, 1);
      expect(result.openedComposer, isFalse);
      expect(calls.single.method, 'sendSmsBatch');
      expect(calls.single.arguments['recipients'], ['09171234567']);
    },
  );
  test(
    'failed native send is not silently converted to a composer success',
    () async {
      submit = false;
      final result = await send(DeviceSmsService());
      expect(result.sent, 0);
      expect(result.errorMessage, isNotNull);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'sendSmsBatch');
    },
  );
  test(
    'denied permission does not repeatedly prompt or invoke the sender',
    () async {
      granted = false;
      final sms = DeviceSmsService();
      expect((await send(sms)).sent, 0);
      expect((await send(sms)).sent, 0);
      expect(permissionRequests, 1);
      expect(calls, isEmpty);
    },
  );
  test(
    'unsupported platforms report failure instead of opening Messages',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect((await send(DeviceSmsService())).sent, 0);
      expect(calls, isEmpty);
    },
  );
}
