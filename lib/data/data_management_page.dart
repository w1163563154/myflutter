import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../journal/journal_store.dart';
import '../journal/vault_service.dart';
import '../records/record_repository.dart';
import 'data_backup.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key, this.journal, this.records, this.vault});
  final JournalStore? journal;
  final SqliteRecordRepository? records;
  final VaultService? vault;
  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  late final _service = DataBackup(
    journal: widget.journal ?? JournalStore.instance,
    records: widget.records ?? SqliteRecordRepository.instance,
    vault: widget.vault ?? VaultService.instance,
  );
  bool _busy = false;
  String? _status;
  String get _stamp =>
      DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  Future<bool> _save(String name, String text, String mime) async {
    final result = await FilePicker.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: mime,
      dialogTitle: '保存数据文件',
    );
    return kIsWeb || result != null;
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await operation();
    } on FormatException catch (e) {
      if (mounted) setState(() => _status = '无法恢复：${e.message}');
    } catch (_) {
      if (mounted) setState(() => _status = '操作失败，数据文件未完成处理，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _saved(bool saved) {
    if (mounted) {
      setState(
        () => _status = saved
            ? (kIsWeb ? '已发起下载，请在浏览器下载列表确认文件已保存' : '文件已保存')
            : '已取消保存',
      );
    }
  }

  Future<bool> _confirm(String title, String message, String button) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(button),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _restore() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '选择手账备份',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    final size = await file.length();
    if (size == null || size > 50 * 1024 * 1024) {
      throw const FormatException('文件无法读取或超过50MB');
    }
    final backup = BackupData.parse(utf8.decode(await file.readAsBytes()));
    final currentHasVault = await _service.vault.isConfigured();
    if (!await _confirm(
      '恢复备份',
      '笔记 ${backup.notes.length} 条，快递 ${backup.records.length} 条，密码条目 ${backup.entries.length} 条。\n\n笔记与快递会新增导入，重复恢复会产生重复记录。${backup.hasVault ? (currentHasVault ? '\n备份中的密码库将完整替换当前密码库，之后使用备份原来的主密码解锁。' : '\n将导入密码库，使用备份原来的主密码解锁。') : '\n备份不含密码库，现有密码库保持不变。'}\n\n先保存当前完整备份，再执行恢复。',
      '保存当前备份',
    )) {
      return;
    }
    final saved = await _save(
      '日常手账-恢复前备份-$_stamp.json',
      await _service.createBackup(),
      'application/json',
    );
    if (!saved) {
      _saved(false);
      return;
    }
    if (kIsWeb &&
        !await _confirm(
          '确认回退文件已保存',
          '浏览器已发起“恢复前备份”下载。请确认下载已完成并保留该文件，再继续恢复。',
          '已保存，继续恢复',
        )) {
      return;
    }
    await _service.restore(backup, replaceVault: backup.hasVault);
    if (mounted) {
      await _confirm('恢复完成', '笔记和快递已新增导入，密码库保持加密并已锁定。', '完成');
      if (!mounted) return;
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
        automaticallyImplyLeading: !_busy,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '把记录妥善收好',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '导出用于查看，备份用于迁移和恢复。所有操作都在本机完成。',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 24),
              _action(
                Icons.description_outlined,
                '导出普通笔记',
                '全部笔记 · CSV，可用 Excel 打开',
                () => _run(
                  () async => _saved(
                    await _save(
                      '日常手账-笔记-$_stamp.csv',
                      await _service.exportNotes(),
                      'text/csv;charset=utf-8',
                    ),
                  ),
                ),
              ),
              _action(
                Icons.inventory_2_outlined,
                '导出快递记录',
                '所有日期 · CSV，电话和编号按文本列导入可保留前导零',
                () => _run(
                  () async => _saved(
                    await _save(
                      '日常手账-快递-$_stamp.csv',
                      await _service.exportRecords(),
                      'text/csv;charset=utf-8',
                    ),
                  ),
                ),
              ),
              _action(
                Icons.backup_outlined,
                '备份全部数据',
                '笔记、快递、加密密码库 · JSON',
                () => _run(
                  () async => _saved(
                    await _save(
                      '日常手账-全部备份-$_stamp.json',
                      await _service.createBackup(),
                      'application/json',
                    ),
                  ),
                ),
              ),
              _action(
                Icons.restore_outlined,
                '从备份恢复',
                '先检查内容，再确认导入',
                () => _run(_restore),
              ),
              const SizedBox(height: 16),
              const Text(
                '密码库只以密文写入备份，不导出明文密码。普通笔记和快递在文件中未加密，请妥善保管。备份不能代替密码库主密码。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: Color(0xFF917D67),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_status!, style: const TextStyle(height: 1.6)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: _busy ? null : onTap,
    ),
  );
}
