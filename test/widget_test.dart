import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ruview_client/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RuViewApp()));
    expect(find.text('概览'), findsAtLeast(1));
    expect(find.text('未连接'), findsWidgets);
    expect(find.text('体征'), findsOneWidget);
    expect(find.text('姿态'), findsOneWidget);
    expect(find.text('区域'), findsOneWidget);
    expect(find.text('安全'), findsOneWidget);
  });
}
