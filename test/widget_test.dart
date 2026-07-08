import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ruview_client/main.dart';

void main() {
  testWidgets('App renders debug screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RuViewApp()));
    expect(find.text('RuView 调试'), findsOneWidget);
    expect(find.text('暂无消息，点击连接开始'), findsOneWidget);
  });
}
