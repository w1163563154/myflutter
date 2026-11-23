import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/records/record.dart';
import 'package:myflutter/records/record_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;
  late SqliteRecordRepository repository;
  final day = DateTime(2026, 11, 13);

  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('local_records_test_');
    repository = SqliteRecordRepository(
      factory: databaseFactoryFfi,
      path: '${dir.path}/records.db',
    );
  });
  tearDown(() async {
    await repository.close();
    await dir.delete(recursive: true);
  });

  test('database pages are 15 rows and dates include hidden pages', () async {
    for (var i = 0; i < 32; i++) {
      await repository.add(
        LocalRecord(
          date: day,
          name: '取件$i',
          createdAt: DateTime(2026, 11, 13, 0, i),
        ),
      );
    }
    await repository.add(
      LocalRecord(date: day.subtract(const Duration(days: 1)), name: '历史取件'),
    );
    final first = await repository.query(day, limit: 15);
    final second = await repository.query(day, limit: 15, offset: 15);
    final last = await repository.query(day, limit: 15, offset: 30);
    expect([first.length, second.length, last.length], [15, 15, 2]);
    expect({
      ...first.map((r) => r.id),
      ...second.map((r) => r.id),
      ...last.map((r) => r.id),
    }, hasLength(32));
    expect(await repository.count(day), 32);
    expect(await repository.count(day, keyword: '取件'), 33);
    expect(await repository.datesInMonth(day), {'2026-11-12', '2026-11-13'});
    expect(await repository.datesInMonth(DateTime(2026, 12)), isEmpty);
  });

  test(
    'edit delete and restore preserve record identity after reopen',
    () async {
      await repository.add(LocalRecord(date: day, name: '原姓名', number: '0007'));
      final original = (await repository.query(day)).single;
      final nextDay = day.add(const Duration(days: 1));
      final edited = LocalRecord(
        id: original.id,
        date: nextDay,
        name: '新姓名',
        phone: '00123',
        number: '0008',
        createdAt: original.createdAt,
      );
      await repository.update(edited);
      await repository.close();
      expect(await repository.query(day), isEmpty);
      final saved = (await repository.query(nextDay)).single;
      expect(saved.id, original.id);
      expect(saved.createdAt, original.createdAt);
      expect(saved.name, '新姓名');
      await repository.delete(saved.id!);
      expect(await repository.query(nextDay), isEmpty);
      await expectLater(repository.update(edited), throwsStateError);
      await repository.add(saved);
      await repository.close();
      expect((await repository.query(nextDay)).single.id, original.id);
    },
  );

  test(
    'persists after reopening, trims text and preserves leading zeros',
    () async {
      await repository.add(
        LocalRecord(date: day, name: ' 张三 ', phone: ' 00123 ', number: '0007'),
      );
      await repository.close();
      final rows = await repository.query(day);
      expect(rows.single.name, '张三');
      expect(rows.single.phone, '00123');
      expect(rows.single.number, '0007');
      expect(rows.single.note, '未填写');
      expect(rows.single.id, isNotNull);
      expect(await repository.query(day.add(const Duration(days: 1))), isEmpty);
    },
  );

  test(
    'searches all dates literally and empty search filters selected date',
    () async {
      final time = DateTime(2026, 11, 13, 12);
      await repository.add(
        LocalRecord(
          date: day,
          name: 'Alice张',
          phone: '010-123',
          number: '0007',
          note: "100%_O'Reilly",
          createdAt: time,
        ),
      );
      await repository.add(
        LocalRecord(date: day, name: '李四', number: '0007', createdAt: time),
      );
      await repository.add(
        LocalRecord(
          date: day.subtract(const Duration(days: 1)),
          name: 'Alice张',
          createdAt: time,
        ),
      );
      for (final keyword in ['alice', '张', '010', '7', '%_', "O'Reilly"]) {
        expect(
          await repository.query(day, keyword: keyword),
          isNotEmpty,
          reason: keyword,
        );
      }
      expect((await repository.query(day, keyword: '%')).length, 1);
      expect((await repository.query(day, keyword: '_')).length, 1);
      expect(await repository.query(day, keyword: "' OR 1=1 --"), isEmpty);
      expect((await repository.query(day)).map((e) => e.name), [
        '李四',
        'Alice张',
      ]);
      expect((await repository.query(day, keyword: '  ')).length, 2);
      final allDays = await repository.query(day, keyword: 'Alice');
      expect(allDays, hasLength(2));
      expect(allDays.first.date, day);
      expect(allDays.last.date, day.subtract(const Duration(days: 1)));
    },
  );

  test('blank fields persist defaults after reopening', () async {
    await repository.add(LocalRecord(date: day, name: '   '));
    await repository.close();
    final saved = (await repository.query(day)).single;
    expect([
      saved.name,
      saved.phone,
      saved.number,
      saved.note,
    ], everyElement('未填写'));
  });
}
