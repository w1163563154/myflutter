import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/solar_system_page.dart';

void main() {
  testWidgets('pan mode and Moon focus are selectable after zoom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolarSystemPage(
          sceneBuilder: (context, model, reset) =>
              Text('pan:${model.panMode} focus:${model.focusIndex}'),
        ),
      ),
    );
    await tester.tap(find.text('平移'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pan:true'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('月球').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('月球').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('focus:8'), findsOneWidget);
    await tester.tap(find.byTooltip('恢复视角'));
    await tester.pumpAndSettle();
    expect(find.textContaining('focus:-2'), findsOneWidget);
  });
  testWidgets('controls pause, change speed, toggle overlays and reset view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolarSystemPage(
          sceneBuilder: (context, model, reset) => Text(
            'time:${model.paused} speed:${model.speed} labels:${model.showLabels} orbits:${model.showOrbits} reset:${reset.value}',
          ),
        ),
      ),
    );
    expect(find.textContaining('time:false'), findsOneWidget);
    await tester.tap(find.byTooltip('暂停'));
    await tester.pumpAndSettle();
    expect(find.textContaining('time:true'), findsOneWidget);
    await tester.tap(find.byType(FilterChip).at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining('labels:false'), findsOneWidget);
    await tester.tap(find.byType(FilterChip).at(0));
    await tester.pumpAndSettle();
    expect(find.textContaining('orbits:false'), findsOneWidget);
    await tester.tap(find.byTooltip('恢复视角'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reset:1'), findsOneWidget);
    await tester.tapAt(
      tester.getBottomRight(find.byType(Slider)) - const Offset(25, 12),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('speed:4.0'), findsOneWidget);
  });
}
