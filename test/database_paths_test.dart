import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/records/database_paths.dart';
import 'package:myflutter/records/record_repository.dart';
import 'package:myflutter/records/record.dart';
import 'package:myflutter/journal/journal_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('root database paths keep file names instead of URL authorities', () {
    expect(localDatabasePath('/', 'journal.db'), '/journal.db');
    expect(localDatabasePath('/', 'local_records.db'), '/local_records.db');
    expect(localDatabasePath('/data', 'journal.db'), '/data/journal.db');
  });
  test('legacy tables copy once with IDs and original file preserved', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('journal_migration_');
    final f = databaseFactoryFfi;
    final sourcePath = '${dir.path}/legacy.db';
    final old = await f.openDatabase(sourcePath);
    await old.execute(
      'CREATE TABLE notes(id INTEGER PRIMARY KEY, title TEXT, body TEXT, updated INTEGER)',
    );
    await old.insert('notes', {
      'id': 8,
      'title': '旧笔记',
      'body': '保留内容',
      'updated': 123,
    });
    await old.close();
    final rows = await readLegacyTables(f, sourcePath, ['notes', 'missing']);
    final store = JournalStore(factory: f, path: '${dir.path}/journal.db');
    final db = await store.database;
    await db.transaction((txn) => restoreLegacyTables(txn, rows));
    expect((await store.notes()).single.id, 8);
    final records = SqliteRecordRepository(
      factory: f,
      path: '${dir.path}/records.db',
    );
    await records.add(
      LocalRecord(date: DateTime(2026), name: '取件人', number: '0001'),
    );
    expect((await records.query(DateTime(2026))).single.number, '0001');
    expect((await store.notes()).single.body, '保留内容');
    expect(
      (await readLegacyTables(f, sourcePath, ['notes']))['notes']!.single['id'],
      8,
    );
    await records.close();
    await store.close();
    await dir.delete(recursive: true);
  });
}
