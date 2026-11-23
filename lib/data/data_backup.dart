import 'dart:convert';
import '../journal/journal_store.dart';
import '../journal/vault_service.dart';
import '../records/record_repository.dart';

String encodeCsv(List<List<Object?>> rows) =>
    '\ufeff${rows.map((row) => row.map((v) {
      var text = v?.toString() ?? '';
      if (RegExp(r'^[\s]*[=+@-]').hasMatch(text) || text.startsWith('\t') || text.startsWith('\r')) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }).join(',')).join('\r\n')}\r\n';

class BackupData {
  BackupData._(this.notes, this.records, this.meta, this.entries);
  final List<Map<String, Object?>> notes, records, meta, entries;
  bool get hasVault => meta.isNotEmpty;
  static BackupData parse(String text) {
    if (utf8.encode(text).length > 50 * 1024 * 1024) {
      throw const FormatException('备份文件超过50MB');
    }
    try {
      final root = jsonDecode(text) as Map<String, dynamic>;
      final version = root['version'];
      if (root['format'] != 'daily-journal-backup' ||
          (version != 1 && version != 2)) {
        throw const FormatException('不支持的备份格式或版本');
      }
      List<Map<String, Object?>> table(String name, Map<String, Type> columns) {
        final list = root[name] as List;
        if (list.length > 100000) throw const FormatException('备份记录过多');
        final ids = <int>{};
        return list.map((raw) {
          final row = Map<String, Object?>.from(raw as Map);
          if (row.length != columns.length ||
              columns.keys.any((k) => !row.containsKey(k))) {
            throw const FormatException('备份字段不完整');
          }
          for (final c in columns.entries) {
            final v = row[c.key];
            if ((c.value == int && v is! int) ||
                (c.value == String && v is! String)) {
              throw const FormatException('备份字段类型错误');
            }
            if (v is String && v.length > 1024 * 1024) {
              throw const FormatException('单条内容过长');
            }
          }
          final id = row['id'] as int;
          if (id <= 0 || !ids.add(id)) throw const FormatException('备份记录编号无效');
          return row;
        }).toList();
      }

      final notes = table('notes', {
        'id': int,
        'title': String,
        'body': String,
        'updated': int,
        if (version == 2) 'pinned': int,
      });
      if (version == 2 &&
          notes.any((row) => row['pinned'] != 0 && row['pinned'] != 1)) {
        throw const FormatException('笔记置顶状态无效');
      }
      final records = table('records', {
        'id': int,
        'record_date': String,
        'name': String,
        'phone': String,
        'number': String,
        'note': String,
        'created_at': int,
      });
      final meta = table('vault_meta', {
        'id': int,
        'salt': String,
        'iterations': int,
        'verifier': String,
      });
      final entries = table('vault_entries', {'id': int, 'payload': String});
      for (final row in records) {
        final value = row['record_date'] as String;
        final date = DateTime.parse(value);
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
            date.toIso8601String().substring(0, 10) != value ||
            date.year < 1900 ||
            date.year > 2100 ||
            (row['name'] as String).trim().isEmpty) {
          throw const FormatException('快递日期或姓名无效');
        }
      }
      for (final row in [...notes, ...records]) {
        final stamp = (row['updated'] ?? row['created_at']) as int;
        if (stamp < 0 || stamp > 8640000000000000) {
          throw const FormatException('时间无效');
        }
      }
      if (meta.length > 1 || (entries.isNotEmpty && meta.isEmpty)) {
        throw const FormatException('密码库元数据无效');
      }
      void envelope(String value) {
        final box = jsonDecode(value) as Map<String, dynamic>;
        if (box['v'] != 1 ||
            base64Decode(box['nonce'] as String).length != 12 ||
            base64Decode(box['mac'] as String).length != 16 ||
            base64Decode(box['cipher'] as String).isEmpty) {
          throw const FormatException('密码库密文格式无效');
        }
      }

      if (meta.isNotEmpty) {
        final m = meta.single;
        final rounds = m['iterations'] as int;
        if (m['id'] != 1 ||
            base64Decode(m['salt'] as String).length != 32 ||
            rounds < 1000 ||
            rounds > 2000000) {
          throw const FormatException('密码库参数无效');
        }
        envelope(m['verifier'] as String);
      }
      for (final row in entries) {
        envelope(row['payload'] as String);
      }
      return BackupData._(notes, records, meta, entries);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('备份内容无效或不完整');
    }
  }
}

class DataBackup {
  DataBackup({
    required this.journal,
    required this.records,
    required this.vault,
  });
  final JournalStore journal;
  final SqliteRecordRepository records;
  final VaultService vault;
  Future<String> createBackup() async {
    final j = await journal.database;
    final r = await records.database;
    final data = await j.transaction(
      (txn) async => {
        'notes': await txn.query('notes'),
        'vault_meta': await txn.query('vault_meta'),
        'vault_entries': await txn.query('vault_entries'),
      },
    );
    return jsonEncode({
      'format': 'daily-journal-backup',
      'version': 2,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      ...data,
      'records': await r.query('records'),
    });
  }

  Future<String> exportNotes() async {
    final rows = await (await journal.database).query(
      'notes',
      orderBy: 'updated DESC, id DESC',
    );
    return encodeCsv([
      ['标题', '正文', '更新时间'],
      ...rows.map(
        (r) => [
          r['title'],
          r['body'],
          DateTime.fromMillisecondsSinceEpoch(
            r['updated'] as int,
          ).toIso8601String(),
        ],
      ),
    ]);
  }

  Future<String> exportRecords() async {
    final rows = await (await records.database).query(
      'records',
      orderBy: 'record_date DESC, id DESC',
    );
    return encodeCsv([
      ['日期', '姓名', '电话', '编号', '备注', '创建时间'],
      ...rows.map(
        (r) => [
          r['record_date'],
          r['name'],
          r['phone'],
          r['number'],
          r['note'],
          DateTime.fromMillisecondsSinceEpoch(
            r['created_at'] as int,
          ).toIso8601String(),
        ],
      ),
    ]);
  }

  Future<void> restore(BackupData data, {bool replaceVault = false}) async {
    final j = await journal.database;
    final r = await records.database;
    if (data.hasVault &&
        (await j.query('vault_meta')).isNotEmpty &&
        !replaceVault) {
      throw StateError('需确认替换现有密码库');
    }
    final before = BackupData.parse(await createBackup());
    vault.lock();
    bool recordsCommitted = false;
    try {
      await j.transaction((jt) async {
        for (final row in data.notes) {
          await jt.insert('notes', {...row}..remove('id'));
        }
        if (data.hasVault) {
          await jt.delete('vault_entries');
          await jt.delete('vault_meta');
          for (final row in data.meta) {
            await jt.insert('vault_meta', row);
          }
          for (final row in data.entries) {
            await jt.insert('vault_entries', row);
          }
        }
        await r.transaction((rt) async {
          for (final row in data.records) {
            await rt.insert('records', {...row}..remove('id'));
          }
        });
        recordsCommitted = true;
      });
    } catch (_) {
      if (recordsCommitted) {
        try {
          await r.transaction((txn) async {
            await txn.delete('records');
            for (final row in before.records) {
              await txn.insert('records', row);
            }
          });
        } catch (_) {
          throw StateError('恢复失败且快递回滚失败，请使用恢复前备份还原');
        }
      }
      rethrow;
    }
  }
}
