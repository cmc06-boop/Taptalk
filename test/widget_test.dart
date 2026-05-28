import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('TapTalk app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const TapTalkApp());
    await tester.pump();
    expect(find.text('TapTalk'), findsWidgets);
  });
}
