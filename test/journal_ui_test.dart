import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/journal/journal_theme.dart';
import 'package:myflutter/journal/notes_page.dart';
import 'package:myflutter/journal/journal_store.dart';
import 'package:myflutter/journal/vault_service.dart';

class MemoryJournal extends JournalStore {
  final items = <JournalNote>[];
  @override
  Future<List<JournalNote>> notes([String keyword = '']) async =>
      items.where((n) => (n.title + n.body).contains(keyword)).toList();
  @override
  Future<int> saveNote({
    int? id,
    required String title,
    required String body,
  }) async {
    items.removeWhere((n) => n.id == id);
    items.add(
      JournalNote(id ?? 1, title, body, DateTime(2026, 11, 16, 10, 24)),
    );
    return id ?? 1;
  }
}

void main() {
  test('weekday follows local date', () {
    expect(journalDate(DateTime(2026, 11, 16)), '11月16日 · 周一');
    expect(journalDate(DateTime(2026, 11, 15)), '11月15日 · 周日');
  });
  testWidgets('note add, prominent date and edit', (tester) async {
    final store = MemoryJournal();
    final vault = VaultService(store);
    await tester.pumpWidget(
      MaterialApp(
        theme: journalTheme(),
        home: NotesPage(store: store, vault: vault),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有笔记，记下第一件小事吧'), findsOneWidget);
    await tester.tap(find.text('写一笔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), '日常');
    await tester.enterText(find.byKey(const Key('note-body')), '买花');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('11月16日 · 周一'), findsOneWidget);
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-body')), '买花和取件');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.items.length, 1);
    expect(find.text('买花和取件'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
  });
}
