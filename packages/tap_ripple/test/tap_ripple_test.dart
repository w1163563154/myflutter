import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_ripple/tap_ripple.dart';

void main() {
  testWidgets('rings start at tap, are bounded and expire', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TapRippleDemo()));
    final area = find.byKey(const ValueKey('ripple-area'));
    final point = tester.getTopLeft(area) + const Offset(45, 70);
    await tester.tapAt(point);
    await tester.pump();
    expect(find.byKey(const ValueKey('ripple-ring')), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      find.byKey(const ValueKey('ripple-ring')).evaluate().length,
      lessThanOrEqualTo(8),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ripple-ring')), findsNothing);
    await tester.tapAt(point);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion does not leave active rings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: TapRippleDemo(),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ripple-area')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ripple-ring')), findsNothing);
  });
}
