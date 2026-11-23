import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/data/data_management_page.dart';
import 'package:myflutter/journal/journal_store.dart';
import 'package:myflutter/journal/vault_service.dart';
import 'package:myflutter/records/record_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePicker extends FilePickerPlatform {
  final saved = <String>[];
  String? picked;
  bool cancelSave = false;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (cancelSave) return null;
    saved.add(utf8.decode(bytes));
    return Uri.file('/tmp/$fileName');
  }
}

void main() {
  testWidgets('exports notes and cancelled save is not reported saved', (
    tester,
  ) async {
    sqfliteFfiInit();
    final journal = JournalStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final records = SqliteRecordRepository(
      factory: databaseFactoryFfi,
      path: 'file:page-data?mode=memory&cache=shared',
    );
    final vault = VaultService(journal);
    final picker = FakePicker();
    final original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    await tester.runAsync(() => journal.saveNote(title: '导出测试', body: '正文'));
    await tester.pumpWidget(
      MaterialApp(
        home: DataManagementPage(
          journal: journal,
          records: records,
          vault: vault,
        ),
      ),
    );
    await tester.tap(find.text('导出普通笔记'));
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(picker.saved.single, contains('导出测试'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('文件已保存'), findsOneWidget);
    picker.cancelSave = true;
    await tester.ensureVisible(find.text('导出普通笔记'));
    await tester.tap(find.text('导出普通笔记'));
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('已取消保存'), findsOneWidget);
    expect(picker.saved, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    FilePickerPlatform.instance = original;
    vault.dispose();
    await tester.runAsync(() async {
      await journal.close();
      await records.close();
    });
  });
}
