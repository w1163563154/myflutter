import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/journal/journal_theme.dart';
import 'package:myflutter/records/record_calendar.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Future<Set<String>> Function(DateTime) load, {
    ValueChanged<DateTime?>? result,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: journalTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final date = await showRecordCalendar(
                context,
                initialDate: DateTime(2026, 11, 16),
                loadDates: load,
              );
              result?.call(date);
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('record dots, date selection and confirmation', (tester) async {
    DateTime? selected;
    await open(
      tester,
      (_) async => {'2026-11-03', '2026-11-16'},
      result: (v) => selected = v,
    );
    expect(find.byKey(const ValueKey('record-dot-2026-11-03')), findsOneWidget);
    expect(find.byKey(const ValueKey('record-dot-2026-11-04')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-03')));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 11, 3));
  });

  testWidgets('month switch rejects stale response and retries errors', (
    tester,
  ) async {
    final pending = Completer<Set<String>>();
    var calls = 0;
    await open(tester, (month) async {
      calls++;
      if (month.month == 12 && calls == 2) return pending.future;
      if (month.month == 1 && calls == 3) throw StateError('failed');
      return {'2027-01-02'};
    });
    await tester.tap(find.byTooltip('下个月'));
    await tester.pump();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    expect(find.text('标记加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    pending.complete({'2026-12-02'});
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-dot-2027-01-02')), findsOneWidget);
    expect(find.byKey(const ValueKey('record-dot-2026-12-02')), findsNothing);
  });

  testWidgets('320 width accepts typed date and rejects invalid date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DateTime? selected;
    await open(tester, (_) async => {}, result: (v) => selected = v);
    await tester.tap(find.byTooltip('输入日期'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar-input')),
      '2026-02-31',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('请输入1900–2100年的有效日期'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('calendar-input')),
      '2030-01-04',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2030, 1, 4));
    expect(tester.takeException(), isNull);
  });
}
