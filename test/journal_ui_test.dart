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

class FailingPinJournal extends MemoryJournal {
  FailingPinJournal() {
    items.add(JournalNote(1, '日常', '买花', DateTime(2026, 11, 16)));
  }

  bool fail = true;

  @override
  Future<void> setPinned(int id, bool pinned) async {
    if (fail) throw StateError('write failed');
    final index = items.indexWhere((note) => note.id == id);
    final note = items[index];
    items[index] = JournalNote(
      note.id,
      note.title,
      note.body,
      note.updated,
      pinned: pinned,
    );
    items.sort((a, b) {
      final pins = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      return pins != 0 ? pins : b.updated.compareTo(a.updated);
    });
  }
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'pin changes vertical position in the current search (reduced=$reduced)',
      (tester) async {
        final store = FailingPinJournal()..fail = false;
        store.items.add(JournalNote(2, '取件', '买花', DateTime(2026, 11, 17)));
        store.items.sort((a, b) => b.updated.compareTo(a.updated));
        final vault = VaultService(store);
        await tester.pumpWidget(
          MaterialApp(
            theme: journalTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: NotesPage(store: store, vault: vault),
          ),
        );
        await tester.pumpAndSettle();
        final search = find.byKey(const Key('note-search'));
        await tester.enterText(search, '买花');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        final old = find.text('日常');
        final recent = find.text('取件');
        final initial = tester.getTopLeft(old).dy;
        final expected = tester.getTopLeft(recent).dy;
        final pinButton = find.descendant(
          of: find.ancestor(of: old, matching: find.byType(Card)),
          matching: find.byTooltip('置顶'),
        );
        await tester.tap(pinButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final during = tester.getTopLeft(old).dy;
        if (reduced) {
          expect(during, closeTo(expected, 1));
        } else {
          expect(during, inExclusiveRange(expected, initial));
        }
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(old).dy, closeTo(expected, 1));

        await tester.tap(find.byTooltip('取消置顶'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final duringCancel = tester.getTopLeft(old).dy;
        if (reduced) {
          expect(duringCancel, closeTo(initial, 1));
        } else {
          expect(duringCancel, inExclusiveRange(expected, initial));
        }
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(old).dy, closeTo(initial, 1));
        expect(tester.widget<TextField>(search).controller!.text, '买花');
        await tester.pumpWidget(const SizedBox());
        vault.dispose();
      },
    );
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'only newly saved and edited notes highlight (reduced=$reduced)',
      (tester) async {
        final store = MemoryJournal();
        await store.saveNote(id: 3, title: '另一条', body: '');
        final vault = VaultService(store);
        await tester.pumpWidget(
          MaterialApp(
            theme: journalTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: NotesPage(store: store, vault: vault),
          ),
        );
        await tester.pumpAndSettle();

        Color? cardColor(String title) => tester
            .widget<Card>(
              find.ancestor(of: find.text(title), matching: find.byType(Card)),
            )
            .color;

        for (final title in ['新笔记', '已编辑']) {
          await tester.tap(find.text(title == '新笔记' ? '写一笔' : '新笔记'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('note-title')), title);
          await tester.tap(find.text('保存'));
          for (
            var frame = 0;
            frame < 40 &&
                find
                    .ancestor(of: find.text(title), matching: find.byType(Card))
                    .evaluate()
                    .isEmpty;
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pump();
          expect(cardColor(title), reduced ? isNull : journalSelection);
          expect(cardColor('另一条'), isNull);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expect(cardColor(title), anyOf(isNull, journalPaper));
        }
        await tester.pumpWidget(const SizedBox());
        vault.dispose();
      },
    );
  }

  test('weekday follows local date', () {
    expect(journalDate(DateTime(2026, 11, 16)), '11月16日 · 周一');
    expect(journalDate(DateTime(2026, 11, 15)), '11月15日 · 周日');
  });
  testWidgets(
    'pin control retains an active search and permits retry after failure',
    (tester) async {
      final store = FailingPinJournal();
      final vault = VaultService(store);
      await tester.pumpWidget(
        MaterialApp(
          theme: journalTheme(),
          home: NotesPage(store: store, vault: vault),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('note-search'));
      await tester.enterText(search, '买花');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('置顶'));
      await tester.pumpAndSettle();
      expect(find.text('置顶失败，请重试'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, '买花');
      expect(find.byTooltip('置顶'), findsOneWidget);

      store.fail = false;
      await tester.tap(find.byTooltip('置顶'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消置顶'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, '买花');

      store.fail = true;
      await tester.tap(find.byTooltip('取消置顶'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('取消置顶失败，请重试'), findsOneWidget);
      expect(find.byTooltip('取消置顶'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, '买花');

      store.fail = false;
      await tester.tap(find.byTooltip('取消置顶'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('置顶'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, '买花');

      await tester.pumpWidget(const SizedBox());
      vault.dispose();
    },
  );
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
    final segments = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(
      segments.style?.backgroundColor?.resolve({WidgetState.selected}),
      journalTheme().navigationBarTheme.indicatorColor,
    );
    await tester.tap(find.text('写一笔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), '日常');
    await tester.enterText(find.byKey(const Key('note-body')), '买花');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('11月16日 · 周一'), findsOneWidget);
    final dateY = tester.getTopLeft(find.text('11月16日 · 周一')).dy;
    final titleY = tester.getTopLeft(find.text('日常')).dy;
    final bodyY = tester.getTopLeft(find.text('买花')).dy;
    expect(dateY, lessThan(titleY));
    expect(titleY, lessThan(bodyY));
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
