import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/journal/journal_theme.dart';
import 'package:myflutter/journal/journal_store.dart';
import 'package:myflutter/journal/vault_service.dart';
import 'package:myflutter/journal/vault_page.dart';
import 'package:fake_async/fake_async.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('activity extends idle deadline and idle locks', () async {
    sqfliteFfiInit();
    final store = JournalStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final service = VaultService(store, iterations: 1000);
    await service.setup('test master passphrase');
    fakeAsync((clock) {
      service.activity();
      clock.elapse(const Duration(seconds: 45));
      service.activity();
      clock.elapse(const Duration(seconds: 45));
      expect(service.isUnlocked, true);
      clock.elapse(const Duration(seconds: 16));
      expect(service.isUnlocked, false);
    });
    service.dispose();
    await store.close();
  });
  testWidgets('locks clear detail and unsaved password editor', (tester) async {
    sqfliteFfiInit();
    final store = JournalStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final service = VaultService(store, iterations: 1000);
    await tester.runAsync(() async {
      await service.setup('test master passphrase');
      await service.save(
        name: '测试站点',
        account: '敏感账号',
        password: 'sensitive-pwd',
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: journalTheme(),
        home: Scaffold(body: VaultPage(service: service)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试站点'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sensitive-pwd'), findsNothing);
    await tester.tap(find.text('显示密码'));
    await tester.pumpAndSettle();
    expect(find.text('密码：sensitive-pwd'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('编辑条目'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vault-password')), findsOneWidget);
    // TextInput edits from a soft keyboard must renew the idle deadline too.
    service.activity();
    await tester.pump(const Duration(seconds: 45));
    await tester.enterText(
      find.byKey(const Key('vault-password')),
      'changed-secret',
    );
    await tester.pump(const Duration(seconds: 45));
    expect(service.isUnlocked, true);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vault-password')), findsNothing);
    expect(find.textContaining('sensitive-pwd'), findsNothing);
    expect(find.text('密码库已锁定，返回解锁'), findsOneWidget);
    await tester.tap(find.text('密码库已锁定，返回解锁'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('解锁密码库'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    await tester.runAsync(store.close);
  });
  test('lock invalidates an in-flight unlock', () async {
    sqfliteFfiInit();
    final store = JournalStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final service = VaultService(store, iterations: 1000);
    await service.setup('test master passphrase');
    service.lock();
    final attempt = service.unlock('test master passphrase');
    service.lock();
    await expectLater(attempt, throwsA(anything));
    expect(service.isUnlocked, false);
    service.dispose();
    await store.close();
  });
}
