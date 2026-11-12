import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/main.dart';

void main() {
  for (final title in ['粒子火花动画', '点击水波动画']) {
    testWidgets('$title opens and returns to gallery', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('探索动画'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('gallery scroll survives tab changes', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.drag(find.byType(ListView), const Offset(0, -130));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动画集'));
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      before,
    );
  });
}
