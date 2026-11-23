import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myflutter/journal/journal_store.dart';
import 'package:myflutter/journal/vault_service.dart';

void main() {
  late Directory dir;
  late JournalStore store;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('journal_test_');
    store = JournalStore(
      factory: databaseFactoryFfi,
      path: '${dir.path}/journal.db',
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test('notes persist, edit without duplication and literal search', () async {
    final id = await store.saveNote(title: '日常', body: '100%_Alice');
    await store.close();
    expect((await store.notes('alice')).single.id, id);
    await store.saveNote(id: id, title: '更新', body: '0007');
    expect((await store.notes()).length, 1);
    expect((await store.notes('0007')).single.title, '更新');
    expect(await store.notes('%'), isEmpty);
    await expectLater(
      store.saveNote(title: ' ', body: ''),
      throwsArgumentError,
    );
  });
  test('vault encrypted roundtrip, wrong master, lock and reopen', () async {
    final vault = VaultService(store, iterations: 1000);
    expect(await vault.isConfigured(), false);
    await vault.setup('test master passphrase');
    final id = await vault.save(
      name: '测试站点',
      url: 'example.com',
      account: 'secret-account',
      password: 'secret-pwd-123',
      note: 'secret-note',
    );
    final raw = await store.database;
    final rows = await raw.query('vault_entries');
    expect(rows.toString().contains('secret-pwd'), false);
    expect(rows.toString().contains('secret-account'), false);
    expect((await vault.entries()).single.password, 'secret-pwd-123');
    vault.lock();
    expect(vault.isUnlocked, false);
    await expectLater(vault.entries(), throwsStateError);
    await expectLater(vault.unlock('wrong'), throwsA(anything));
    expect(vault.isUnlocked, false);
    await store.close();
    await vault.unlock('test master passphrase');
    expect((await vault.entries()).single.id, id);
    await vault.save(id: id, name: '修改', password: 'new-secret');
    expect((await vault.entries()).length, 1);
    expect((await vault.entries()).single.password, 'new-secret');
    vault.lock();
  });
  test('tampered ciphertext is rejected', () async {
    final vault = VaultService(store, iterations: 1000);
    await vault.setup('test master passphrase');
    await vault.save(name: '站点', password: 'test-secret');
    await (await store.database).update('vault_entries', {
      'payload': 'corrupt',
    });
    await expectLater(vault.entries(), throwsA(anything));
    vault.lock();
  });
}
