import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/data/data_backup.dart';
import 'package:myflutter/journal/journal_store.dart';
import 'package:myflutter/journal/vault_service.dart';
import 'package:myflutter/records/record.dart';
import 'package:myflutter/records/record_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late JournalStore journal;
  late SqliteRecordRepository records;
  late VaultService vault;
  late DataBackup service;
  setUp(() {
    sqfliteFfiInit();
    journal = JournalStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    records = SqliteRecordRepository(
      factory: databaseFactoryFfi,
      path: 'file:backup-records?mode=memory&cache=shared',
    );
    vault = VaultService(journal, iterations: 1000);
    service = DataBackup(journal: journal, records: records, vault: vault);
  });
  tearDown(() async {
    vault.dispose();
    await journal.close();
    await records.close();
  });
  test('CSV quotes multiline content and neutralizes spreadsheet formulas', () {
    final csv = encodeCsv([
      ['标题', '正文'],
      ['=SUM(A1)', 'a,"b"\nc'],
    ]);
    expect(csv.startsWith('\ufeff'), true);
    expect(csv, contains('"\'=SUM(A1)"'));
    expect(csv, contains('"a,""b""\nc"'));
  });
  test(
    'backup restore preserves ciphertext and unlocks with original master',
    () async {
      await journal.saveNote(title: '日常', body: '正文');
      await records.add(
        LocalRecord(date: DateTime(2026, 11, 16), name: '张三', number: '0007'),
      );
      await vault.setup('test master phrase');
      await vault.save(name: '网站', account: '秘密账号', password: 'secret-pwd');
      final text = await service.createBackup();
      expect(text, isNot(contains('secret-pwd')));
      final backup = BackupData.parse(text);
      expect(backup.notes.length, 1);
      await service.restore(backup, replaceVault: true);
      expect(vault.isUnlocked, false);
      expect(await journal.notes(), hasLength(2));
      expect(await records.query(DateTime(2026, 11, 16)), hasLength(2));
      await vault.unlock('test master phrase');
      expect((await vault.entries()).single.password, 'secret-pwd');
    },
  );
  test(
    'malformed files and unconfirmed vault replacement leave data intact',
    () async {
      await journal.saveNote(title: '保留', body: '');
      await vault.setup('test master phrase');
      final backup = BackupData.parse(await service.createBackup());
      await expectLater(service.restore(backup), throwsStateError);
      expect(await journal.notes(), hasLength(1));
      final json =
          jsonDecode(await service.createBackup()) as Map<String, dynamic>;
      json['version'] = 999;
      expect(() => BackupData.parse(jsonEncode(json)), throwsFormatException);
      json['version'] = 1;
      json['records'] = [
        {'id': 1, 'record_date': '2026-02-31'},
      ];
      expect(() => BackupData.parse(jsonEncode(json)), throwsFormatException);
    },
  );
  test('database failure rolls back imported notes and records', () async {
    await journal.saveNote(title: '保留', body: '');
    await records.add(LocalRecord(date: DateTime(2026), name: '保留'));
    final backup = BackupData.parse(await service.createBackup());
    await (await records.database).execute(
      "CREATE TRIGGER reject_import BEFORE INSERT ON records BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(service.restore(backup), throwsA(anything));
    expect(await journal.notes(), hasLength(1));
    expect(await records.query(DateTime(2026)), hasLength(1));
  });
  test(
    'export excludes vault and empty backup retains current vault',
    () async {
      final empty = BackupData.parse(await service.createBackup());
      await vault.setup('test master phrase');
      await vault.save(
        name: '私密网站',
        account: 'secret-account',
        password: 'secret-pwd',
      );
      await journal.saveNote(title: '+公式', body: '正文');
      await records.add(
        LocalRecord(date: DateTime(2026), name: '张三', phone: '00123'),
      );
      final notesCsv = await service.exportNotes();
      final recordsCsv = await service.exportRecords();
      expect(notesCsv, contains("'+公式"));
      expect(recordsCsv, contains('00123'));
      expect(notesCsv + recordsCsv, isNot(contains('secret-account')));
      await service.restore(empty);
      await vault.unlock('test master phrase');
      expect((await vault.entries()).single.password, 'secret-pwd');
    },
  );
}
