import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/main.dart';

void main() {
  testWidgets('navigation selects all tabs and handles rapid changes', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('探索动画'), findsOneWidget);
    await tester.tap(find.text('视频集'));
    await tester.pumpAndSettle();
    expect(find.text('视频内容即将上线'), findsOneWidget);
    await tester.tap(find.text('我的'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('动画集'));
    await tester.pumpAndSettle();
    expect(find.text('探索动画'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
