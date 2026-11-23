import 'package:sqflite_common/sqlite_api.dart';

import 'database_native.dart' if (dart.library.js_interop) 'database_web.dart';
import 'record.dart';
import 'database_paths.dart';

abstract interface class RecordRepository {
  Future<void> add(LocalRecord record);
  Future<void> update(LocalRecord record);
  Future<void> delete(int id);
  Future<List<LocalRecord>> query(
    DateTime date, {
    String keyword = '',
    int? limit,
    int offset = 0,
  });
  Future<int> count(DateTime date, {String keyword = ''});
  Future<Set<String>> datesInMonth(DateTime month);
}

class SqliteRecordRepository implements RecordRepository {
  SqliteRecordRepository({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;

  static final instance = SqliteRecordRepository();
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _opening;

  Future<Database> _database() => _opening ??= _open();
  Future<Database> get database => _database();

  Future<Database> _open() async {
    try {
      final factory = _factory ?? recordDatabaseFactory;
      final path =
          _path ??
          localDatabasePath(
            await factory.getDatabasesPath(),
            'local_records.db',
          );
      final legacy = await readLegacyTables(
        factory,
        _path == null ? legacyDatabasePath : null,
        ['records'],
      );
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record_date TEXT NOT NULL,
                name TEXT NOT NULL CHECK(length(trim(name)) > 0),
                phone TEXT NOT NULL DEFAULT '',
                number TEXT NOT NULL DEFAULT '',
                note TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL
              )
            ''');
            await db.execute(
              'CREATE INDEX records_date ON records(record_date)',
            );
            await restoreLegacyTables(db, legacy);
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  @override
  Future<void> add(LocalRecord record) async {
    if (record.date.year < 1900 || record.date.year > 2100) {
      throw ArgumentError('日期超出范围');
    }
    await (await _database()).insert('records', {
      if (record.id != null) 'id': record.id,
      ...record.toMap(),
    });
  }

  @override
  Future<void> update(LocalRecord record) async {
    if (record.id == null) throw ArgumentError('缺少记录编号');
    if (record.date.year < 1900 || record.date.year > 2100) {
      throw ArgumentError('日期超出范围');
    }
    final count = await (await _database()).update(
      'records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    if (count != 1) throw StateError('记录已不存在');
  }

  @override
  Future<void> delete(int id) async {
    final count = await (await _database()).delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('记录已不存在');
  }

  @override
  Future<List<LocalRecord>> query(
    DateTime date, {
    String keyword = '',
    int? limit,
    int offset = 0,
  }) async {
    final word = keyword.trim();
    final rows = await (await _database()).query(
      'records',
      where: word.isEmpty
          ? 'record_date = ?'
          : '''(
        instr(lower(name), lower(?)) > 0 OR
        instr(lower(phone), lower(?)) > 0 OR
        instr(lower(number), lower(?)) > 0 OR
        instr(lower(note), lower(?)) > 0)''',
      whereArgs: [
        if (word.isEmpty) dateKey(date),
        if (word.isNotEmpty) ...[word, word, word, word],
      ],
      orderBy: 'record_date DESC, created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalRecord.fromMap).toList();
  }

  @override
  Future<int> count(DateTime date, {String keyword = ''}) async {
    final q = keyword.trim();
    final rows = await (await _database()).rawQuery(
      q.isEmpty
          ? 'SELECT COUNT(*) AS total FROM records WHERE record_date = ?'
          : 'SELECT COUNT(*) AS total FROM records WHERE instr(lower(name),lower(?))>0 OR instr(lower(phone),lower(?))>0 OR instr(lower(number),lower(?))>0 OR instr(lower(note),lower(?))>0',
      q.isEmpty ? [dateKey(date)] : [q, q, q, q],
    );
    return rows.single['total'] as int;
  }

  @override
  Future<Set<String>> datesInMonth(DateTime month) async {
    final rows = await (await _database()).query(
      'records',
      distinct: true,
      columns: ['record_date'],
      where: 'record_date >= ? AND record_date < ?',
      whereArgs: [
        dateKey(DateTime(month.year, month.month)),
        dateKey(DateTime(month.year, month.month + 1)),
      ],
    );
    return rows.map((r) => r['record_date'] as String).toSet();
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
