import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/utils/code_qr_utils.dart';

void main() {
  test('caregiver scanner distinguishes learner and transfer codes', () {
    expect(CodeQrUtils.extractProfileCode('TT-ABCDEFG2'), 'TT-ABCDEFG2');
    expect(CodeQrUtils.extractTransferCode('TR-ABCDEFG2'), 'TR-ABCDEFG2');
    expect(CodeQrUtils.extractTransferCode('TT-ABCDEFG2'), isNull);
    expect(CodeQrUtils.extractProfileCode('TR-ABCDEFG2'), isNull);
  });

  test('transfer codes accept compact and shared-text forms', () {
    expect(CodeQrUtils.extractTransferCode('TRABCDEFG2'), 'TR-ABCDEFG2');
    expect(
      CodeQrUtils.extractTransferCode(
        'TapTalk caregiver transfer code: TR-ABCDEFG2',
      ),
      'TR-ABCDEFG2',
    );
  });
}
