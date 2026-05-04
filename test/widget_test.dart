import 'package:flutter_test/flutter_test.dart';
import 'package:notechat/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteChatApp());
    await tester.pumpAndSettle();
    expect(find.text('微记'), findsOneWidget);
  });
}
