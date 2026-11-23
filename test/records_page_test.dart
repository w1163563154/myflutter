import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/records/record.dart';
import 'package:myflutter/records/record_repository.dart';
import 'package:myflutter/records/records_page.dart';

class MemoryRecords implements RecordRepository {
  final records = <LocalRecord>[];
  bool failRead = false;
  bool failSave = false;
  bool failDelete = false;
  bool failMore = false;
  final requestedOffsets = <int>[];
  DateTime? queriedDay;
  @override
  Future<List<LocalRecord>> query(
    DateTime date, {
    String keyword = '',
    int? limit,
    int offset = 0,
  }) async {
    queriedDay = date;
    requestedOffsets.add(offset);
    if (failRead) throw StateError('read failed');
    if (failMore && offset > 0) throw StateError('page failed');
    return records
        .where(
          (r) =>
              (keyword.trim().isNotEmpty || dateKey(r.date) == dateKey(date)) &&
              [
                r.name,
                r.phone,
                r.number,
                r.note,
              ].any((s) => s.toLowerCase().contains(keyword.toLowerCase())),
        )
        .skip(offset)
        .take(limit ?? records.length)
        .toList();
  }

  @override
  Future<int> count(DateTime date, {String keyword = ''}) async =>
      (await query(date, keyword: keyword)).length;
  @override
  Future<Set<String>> datesInMonth(DateTime month) async => records
      .where((r) => r.date.year == month.year && r.date.month == month.month)
      .map((r) => dateKey(r.date))
      .toSet();

  @override
  Future<void> add(LocalRecord record) async {
    if (failSave) throw StateError('save failed');
    records.add(
      LocalRecord(
        id: record.id ?? records.length + 1,
        date: record.date,
        name: record.name,
        phone: record.phone,
        number: record.number,
        note: record.note,
        createdAt: record.createdAt,
      ),
    );
  }

  @override
  Future<void> update(LocalRecord record) async {
    if (failSave) throw StateError('save failed');
    records[records.indexWhere((r) => r.id == record.id)] = record;
  }

  @override
  Future<void> delete(int id) async {
    if (failDelete) throw StateError('delete failed');
    records.removeWhere((r) => r.id == id);
  }
}

Future<void> showPage(WidgetTester tester, RecordRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(home: RecordsPage(repository: repository)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads 15 per page and retries failed continuation', (
    tester,
  ) async {
    final repository = MemoryRecords();
    for (var i = 0; i < 32; i++) {
      await repository.add(LocalRecord(date: DateTime.now(), name: '姓名$i'));
    }
    await showPage(tester, repository);
    expect(find.text('共 32 条记录 · 已加载 15 条'), findsOneWidget);
    repository.failMore = true;
    final list = find.byKey(const PageStorageKey('records-list'));
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('加载失败，点击重试'),
      500,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    repository.failMore = false;
    await tester.tap(find.text('加载失败，点击重试'));
    await tester.pumpAndSettle();
    expect(repository.requestedOffsets, contains(15));
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(repository.requestedOffsets, contains(30));
    await tester.scrollUntilVisible(
      find.text('已加载全部记录'),
      500,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.text('已加载全部记录'), findsOneWidget);
  });
  testWidgets('search spans dates and clearing restores selected day', (
    tester,
  ) async {
    final repository = MemoryRecords();
    await repository.add(LocalRecord(date: DateTime.now(), name: '当天取件'));
    await repository.add(
      LocalRecord(
        date: DateTime.now().subtract(const Duration(days: 2)),
        name: '历史取件',
      ),
    );
    await showPage(tester, repository);
    expect(find.text('姓名：历史取件'), findsNothing);
    await tester.enterText(find.byKey(const Key('record-search')), '取件');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('姓名：当天取件'), findsOneWidget);
    expect(find.text('姓名：历史取件'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text('姓名：历史取件'), findsNothing);
    expect(find.text('姓名：当天取件'), findsOneWidget);
  });
  testWidgets('tap edits, left swipe deletes and undo restores', (
    tester,
  ) async {
    final repository = MemoryRecords();
    await repository.add(
      LocalRecord(
        date: DateTime.now(),
        name: '张三',
        phone: '00123',
        number: '0007',
      ),
    );
    await showPage(tester, repository);
    await tester.tap(find.text('姓名：张三'));
    await tester.pumpAndSettle();
    expect(find.text('修改快递'), findsOneWidget);
    expect(find.text('0007'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('record-name')), '李四');
    repository.failSave = true;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    repository.failSave = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.records.single.id, 1);
    expect(find.text('姓名：李四'), findsOneWidget);
    repository.failDelete = true;
    await tester.drag(
      find.byKey(const ValueKey('courier-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));
    final rowWidth = tester
        .getSize(find.byKey(const ValueKey('courier-1')))
        .width;
    final deleteWidth = tester
        .getSize(find.byKey(const ValueKey('delete-courier-1')))
        .width;
    expect(deleteWidth, closeTo(rowWidth / 4, 1));
    expect(find.text('删除这条快递记录？'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('delete-courier-1')));
    await tester.pumpAndSettle();
    expect(find.text('删除这条快递记录？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('delete-courier-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除失败，请重试'), findsOneWidget);
    repository.failDelete = false;
    await tester.tap(find.byKey(const ValueKey('delete-courier-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(repository.records, isEmpty);
    repository.failSave = true;
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(find.text('恢复失败'), findsOneWidget);
    repository.failSave = false;
    await tester.tap(find.text('重试恢复'));
    await tester.pumpAndSettle();
    expect(repository.records.single.id, 1);
    expect(find.text('姓名：李四'), findsOneWidget);
  });

  testWidgets('pending deletion keeps undo after changing search', (
    tester,
  ) async {
    final repository = SlowDeleteRecords();
    await repository.add(LocalRecord(date: DateTime.now(), name: '张三'));
    await showPage(tester, repository);
    await tester.drag(
      find.byKey(const ValueKey('courier-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-courier-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('record-search')), '其他');
    await tester.pump(const Duration(milliseconds: 400));
    repository.pending.complete();
    await tester.pumpAndSettle();
    expect(repository.records, isEmpty);
    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(repository.records.single.name, '张三');
  });
  testWidgets('today default, save, search and clear', (tester) async {
    final repository = MemoryRecords();
    await showPage(tester, repository);
    expect(dateKey(repository.queriedDay!), dateKey(DateTime.now()));
    expect(find.text('当天暂无记录'), findsOneWidget);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-name')), '张三');
    await tester.enterText(find.byKey(const Key('record-phone')), '00123');
    await tester.enterText(find.byKey(const Key('record-number')), '0007');
    await tester.enterText(find.byKey(const Key('record-note')), '备注');
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.records.single.phone, '00123');
    expect(find.text('姓名：张三'), findsOneWidget);
    expect(find.text('电话：00123'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('record-search')), '找不到');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('未找到匹配记录'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text('姓名：张三'), findsOneWidget);
  });

  testWidgets('empty and whitespace fields save with defaults', (tester) async {
    final repository = MemoryRecords();
    await showPage(tester, repository);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('名字 *'), findsNothing);
    expect(find.text('编号 *'), findsNothing);
    await tester.enterText(find.byKey(const Key('record-name')), '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = repository.records.single;
    expect([
      saved.name,
      saved.phone,
      saved.number,
      saved.note,
    ], everyElement('未填写'));
    expect(dateKey(saved.date), dateKey(DateTime.now()));
    expect(find.text('编号：未填写'), findsOneWidget);
  });

  testWidgets('read retry and save failure preserve input', (tester) async {
    final repository = MemoryRecords()..failRead = true;
    await showPage(tester, repository);
    expect(find.text('加载失败，请重试'), findsOneWidget);
    repository.failRead = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('当天暂无记录'), findsOneWidget);
    repository.failSave = true;
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-name')), '保留输入');
    await tester.enterText(find.byKey(const Key('record-number')), '0008');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('保留输入'), findsOneWidget);
    repository.failSave = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.records.single.name, '保留输入');
  });

  testWidgets('date picker filters records and retains search', (tester) async {
    final repository = MemoryRecords();
    await showPage(tester, repository);
    await tester.enterText(find.byKey(const Key('record-search')), '张');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('选择日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('输入日期'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '2026-11-12');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(dateKey(repository.queriedDay!), '2026-11-12');
    expect(find.text('张'), findsOneWidget);
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(dateKey(repository.queriedDay!), dateKey(DateTime.now()));
  });

  testWidgets('older requests never replace latest search results', (
    tester,
  ) async {
    final repository = DelayedRecords();
    await tester.pumpWidget(
      MaterialApp(home: RecordsPage(repository: repository)),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('record-search')), 'new');
    await tester.pump(const Duration(milliseconds: 350));
    repository.requests.last.complete([
      LocalRecord(date: DateTime.now(), name: 'new'),
    ]);
    await tester.pumpAndSettle();
    repository.requests.first.complete([
      LocalRecord(date: DateTime.now(), name: 'old'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('姓名：new'), findsOneWidget);
    expect(find.text('old'), findsNothing);
  });
}

class DelayedRecords implements RecordRepository {
  final requests = <Completer<List<LocalRecord>>>[];
  @override
  Future<List<LocalRecord>> query(
    DateTime date, {
    String keyword = '',
    int? limit,
    int offset = 0,
  }) {
    final request = Completer<List<LocalRecord>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> add(LocalRecord record) async {}
  @override
  Future<void> update(LocalRecord record) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<int> count(DateTime date, {String keyword = ''}) async => 1;
  @override
  Future<Set<String>> datesInMonth(DateTime month) async => {};
}

class SlowDeleteRecords extends MemoryRecords {
  final pending = Completer<void>();
  @override
  Future<void> delete(int id) async {
    await pending.future;
    await super.delete(id);
  }
}
