import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:particle_sparks/particle_sparks.dart';

void main() {
  testWidgets('each shape bursts, restarts, restores and disposes safely', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ParticleSparksDemo()));
    for (final label in ['圆形', '三角形', '正方形']) {
      final shape = find.bySemanticsLabel(label);
      expect(shape, findsOneWidget);
      await tester.ensureVisible(shape);
      await tester.pumpAndSettle();
      await tester.tap(shape);
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.bySemanticsLabel('$label，正在碎裂'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('$label，正在碎裂'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    await tester.tap(find.bySemanticsLabel('正方形'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion keeps shapes available', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ParticleSparksDemo(),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('圆形'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('圆形'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
