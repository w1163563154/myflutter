import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/home_shell.dart';
import 'package:myflutter/journal/journal_theme.dart';
import 'journal_ui_test.dart' show MemoryJournal;

void main() {
  testWidgets('two tabs preserve notes search and tools return', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: journalTheme(),
        home: HomeShell(store: MemoryJournal()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('随手记'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('note-search')), '保留关键词');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('快递记录'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-search')), findsOneWidget);
    await tester.tap(find.text('个人记录'));
    await tester.pumpAndSettle();
    expect(find.text('保留关键词'), findsOneWidget);
    await tester.tap(find.text('小工具'));
    await tester.pumpAndSettle();
    expect(find.text('3D 太阳系'), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.text('保留关键词'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
